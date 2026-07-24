# frozen_string_literal: true

require "json"
require "securerandom"

module ::DiscourseAffiliate
  class RulesCache
    KEY = "discourse_affiliate:rules:v1"
    LOCK_KEY = "discourse_affiliate:rules:lock:v1"
    DEFAULT_TTL_SECONDS = 300
    MAX_STALE_SECONDS = 1.hour.to_i

    class << self
      def cached
        read
      end

      def current(force: false)
        cached = read
        return cached if !force && fresh?(cached)

        refresh(cached: cached) || stale(cached)
      end

      def refresh!(force: true)
        current(force: force)
      end

      def clear!
        Discourse.redis.del(KEY)
      rescue StandardError
        false
      end

      private

      def refresh(cached:)
        lock_token = SecureRandom.hex(8)
        acquired = Discourse.redis.set(LOCK_KEY, lock_token, nx: true, ex: 5)
        return stale(cached) unless acquired

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = ::DiscourseAffiliate::PlatformClient.new.fetch_rules(etag: cached&.dig("etag"))
        now = Time.zone.now

        payload =
          if response[:status] == :not_modified
            raise ::DiscourseAffiliate::PlatformClient::Error, "cache_missing" if cached.blank?
            cached.fetch("payload")
          else
            validate_payload!(response.fetch(:body))
          end

        ttl = payload.fetch("cache_ttl_seconds", DEFAULT_TTL_SECONDS).to_i.clamp(30, 3600)
        entry = {
          "payload" => payload,
          "etag" => response[:etag].presence || cached&.dig("etag"),
          "fetched_at" => now.iso8601(3),
          "expires_at" => (now + ttl.seconds).iso8601(3),
        }
        Discourse.redis.setex(KEY, ttl + MAX_STALE_SECONDS, JSON.generate(entry))

        version = payload["version"].to_s.first(64)
        rule_count = Array(payload["rules"]).length
        ::DiscourseAffiliate::StateStore.write(
          cache_version: version,
          cache_rule_count: rule_count,
          cache_fetched_at: entry["fetched_at"],
          cache_expires_at: entry["expires_at"],
          last_rules_success_at: now.iso8601(3),
          last_rules_error_code: nil,
          last_rules_latency_ms: response[:latency_ms].to_i,
        )
        ::DiscourseAffiliate::EventLog.record(
          event: :rules_fetch,
          result: response[:status] == :not_modified ? :not_modified : :success,
          details: {
            latency_ms: response[:latency_ms],
            rule_count: rule_count,
            http_status: response[:http_status] || 304,
          },
        )
        entry
      rescue ::DiscourseAffiliate::PlatformUrl::Invalid => error
        record_error("misconfigured", error)
        nil
      rescue ::DiscourseAffiliate::PlatformClient::Error => error
        record_error(error.code, error)
        nil
      ensure
        Discourse.redis.del(LOCK_KEY) if defined?(acquired) && acquired
      end

      def read
        raw = Discourse.redis.get(KEY)
        raw.present? ? JSON.parse(raw) : nil
      rescue JSON::ParserError, StandardError
        nil
      end

      def fresh?(entry)
        return false if entry.blank?

        Time.zone.parse(entry["expires_at"].to_s).future?
      rescue ArgumentError, TypeError
        false
      end

      def stale(entry)
        return nil if entry.blank?

        fetched_at = Time.zone.parse(entry["fetched_at"].to_s)
        Time.zone.now - fetched_at <= MAX_STALE_SECONDS ? entry : nil
      rescue ArgumentError, TypeError
        nil
      end

      def validate_payload!(payload)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless payload.is_a?(Hash)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless payload["api_version"].to_i == 1
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless payload["rules"].is_a?(Array)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" if payload["rules"].length > 500

        payload
      end

      def record_error(code, error)
        now = Time.zone.now
        result = event_result(code)
        ::DiscourseAffiliate::StateStore.write(
          last_rules_error_at: now.iso8601(3),
          last_rules_error_code: code.to_s.first(64),
        )
        ::DiscourseAffiliate::EventLog.record(
          event: :rules_fetch,
          result: result,
          severity: :error,
          details: { http_status: error.respond_to?(:http_status) ? error.http_status : nil },
        )
        ::DiscourseAffiliate::SafeLog.warn("rules_fetch_failed", error: error, http_status: error.respond_to?(:http_status) ? error.http_status : nil)
      end

      def event_result(code)
        return "misconfigured" if %w[missing invalid https_required host_missing credentials_not_allowed query_not_allowed fragment_not_allowed path_not_allowed host_not_allowed ip_literal_not_allowed token_missing].include?(code.to_s)
        return code.to_s if ::DiscourseAffiliate::EventLog::RESULTS.include?(code.to_s)
        return "server_error" if code.to_s == "http_error"
        return "invalid_response" if %w[invalid_json response_too_large cache_missing].include?(code.to_s)

        "unknown"
      end
    end
  end
end
