# frozen_string_literal: true

require "json"
require "securerandom"

module ::DiscourseAffiliate
  class EventLog
    KEY = "discourse_affiliate:admin_events:v1"
    MAX_EVENTS = 300
    RETENTION_SECONDS = 14.days.to_i
    DEFAULT_LIMIT = 100
    MAX_LIMIT = 200

    EVENTS = %w[configuration rules_fetch resolve_request].freeze
    RESULTS = %w[
      success
      not_modified
      disabled
      misconfigured
      timeout
      unauthorized
      forbidden
      rate_limited
      server_error
      invalid_response
      unavailable
      skipped
      unknown
    ].freeze
    SEVERITIES = %w[info warning error].freeze
    DETAIL_KEYS = %w[http_status latency_ms link_count result_count rule_count setting].freeze

    class << self
      def record(event:, result:, severity: :info, details: {}, occurred_at: Time.zone.now)
        occurred_at = occurred_at.in_time_zone
        payload = {
          v: 1,
          id: SecureRandom.hex(8),
          occurred_at: occurred_at.iso8601(3),
          occurred_at_ms: (occurred_at.to_f * 1000).to_i,
          event: sanitize(event, EVENTS),
          result: sanitize(result, RESULTS),
          severity: sanitize(severity, SEVERITIES),
          details: sanitize_details(details),
        }

        redis.zadd(KEY, occurred_at.to_f, JSON.generate(payload))
        prune!
        true
      rescue StandardError => error
        ::DiscourseAffiliate::SafeLog.warn("event_log_write_failed", error: error)
        false
      end

      def recent(limit: DEFAULT_LIMIT)
        prune!
        normalized_limit = limit.to_i
        normalized_limit = DEFAULT_LIMIT if normalized_limit <= 0
        normalized_limit = normalized_limit.clamp(1, MAX_LIMIT)
        redis.zrevrange(KEY, 0, normalized_limit - 1).filter_map { |entry| parse(entry) }
      rescue StandardError => error
        ::DiscourseAffiliate::SafeLog.warn("event_log_read_failed", error: error)
        []
      end

      private

      def redis
        Discourse.redis
      end

      def prune!
        cutoff = Time.now.to_f - RETENTION_SECONDS
        redis.zremrangebyscore(KEY, 0, cutoff)
        count = redis.zcard(KEY).to_i
        redis.zremrangebyrank(KEY, 0, count - MAX_EVENTS - 1) if count > MAX_EVENTS
        redis.expire(KEY, RETENTION_SECONDS)
      end

      def parse(serialized)
        raw = JSON.parse(serialized.to_s)
        {
          id: raw["id"].to_s,
          occurred_at: raw["occurred_at"].to_s,
          event: sanitize(raw["event"], EVENTS),
          result: sanitize(raw["result"], RESULTS),
          severity: sanitize(raw["severity"], SEVERITIES),
          details: sanitize_details(raw["details"] || {}),
        }
      rescue JSON::ParserError, TypeError
        nil
      end

      def sanitize(value, allowed)
        normalized = value.to_s
        allowed.include?(normalized) ? normalized : "unknown"
      end

      def sanitize_details(details)
        return {} unless details.respond_to?(:each)

        details.each_with_object({}) do |(key, value), output|
          normalized_key = key.to_s
          next unless DETAIL_KEYS.include?(normalized_key)

          output[normalized_key] =
            if normalized_key == "setting"
              value.to_s.first(80)
            else
              value.to_i
            end
        end
      end
    end
  end
end
