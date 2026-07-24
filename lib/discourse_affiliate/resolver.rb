# frozen_string_literal: true

require "digest"
require "set"
require "uri"
require "securerandom"

module ::DiscourseAffiliate
  class Resolver
    MAX_LINKS = 50

    def resolve(post:, links:, user:)
      return response([], reason: "disabled") unless SiteSetting.affiliate_resolver_enabled
      return response([], reason: "staff_only") if SiteSetting.affiliate_resolver_local_staff_only && !user.staff?

      cache = ::DiscourseAffiliate::RulesCache.current
      return response([], reason: "rules_unavailable") if cache.blank?

      payload = cache.fetch("payload")
      cohort = cohort_for(user)
      matcher = ::DiscourseAffiliate::RuleMatcher.new(
        payload: payload,
        category_id: post.topic.category_id,
        staff: user.staff?,
        cohort: cohort,
      )
      return response([], reason: "platform_disabled") unless matcher.enabled?

      cooked_urls = ::DiscourseAffiliate::PostLinkExtractor.new(post.cooked).eligible_urls
      candidates = []
      matches = {}
      seen_keys = Set.new

      Array(links).first(MAX_LINKS).each do |link|
        key = link[:key].to_s
        url = link[:url].to_s
        next unless key.match?(/\A[A-Za-z0-9_-]{1,64}\z/)
        next if seen_keys.include?(key)
        next unless url.bytesize <= 4096
        next unless cooked_urls.include?(url)

        matched = matcher.match(url)
        next unless matched

        seen_keys << key
        candidates << { key: key, url: url }
        matches[key] = matched
      end

      return response([], reason: "no_eligible_links") if candidates.empty?

      request_id = SecureRandom.uuid
      platform_payload = {
        request_id: request_id,
        plugin_version: ::DiscourseAffiliate::PLUGIN_VERSION,
        context: {
          kind: "public_post",
          category_id: post.topic.category_id,
          topic_id: post.topic_id,
          staff: user.staff?,
          cohort: cohort,
          source_ref_hash: ::DiscourseAffiliate::SourceReference.hash(post.id),
        },
        links: candidates,
      }

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = ::DiscourseAffiliate::PlatformClient.new.resolve(platform_payload)
      parsed = validate_response!(result.fetch(:body), request_id, candidates.map { |candidate| candidate[:key] })
      local_observe_only = SiteSetting.affiliate_resolver_local_observe_only

      client_results = parsed.map do |item|
        key = item.fetch("key")
        rewrite = validate_rewrite(item["rewrite"])
        should_apply =
          !local_observe_only &&
          !matches.fetch(key).observe_only &&
          item["decision"] == "rewritten" &&
          rewrite.present?

        {
          key: key,
          decision: item["decision"].to_s.first(64),
          reason_code: item["reason_code"].to_s.first(64),
          applied: should_apply,
          rewrite: should_apply ? rewrite : nil,
        }
      end

      latency_ms = elapsed_ms(started_at)
      now = Time.zone.now
      ::DiscourseAffiliate::StateStore.write(
        last_resolve_success_at: now.iso8601(3),
        last_resolve_error_code: nil,
        last_resolve_latency_ms: latency_ms,
        last_resolve_link_count: candidates.length,
        last_resolve_result_count: client_results.length,
      )
      if SiteSetting.affiliate_resolver_debug_logging_enabled
        ::DiscourseAffiliate::EventLog.record(
          event: :resolve_request,
          result: :success,
          details: {
            latency_ms: latency_ms,
            link_count: candidates.length,
            result_count: client_results.length,
            http_status: result[:http_status],
          },
        )
      end

      response(client_results, reason: "success")
    rescue ::DiscourseAffiliate::PlatformClient::Error => error
      record_error(error.code, error)
      response([], reason: "platform_unavailable")
    rescue StandardError => error
      record_error("invalid_response", error)
      response([], reason: "platform_unavailable")
    end

    private

    def response(results, reason:)
      {
        observe_only: SiteSetting.affiliate_resolver_local_observe_only,
        reason: reason,
        results: results,
      }
    end

    def validate_response(body, request_id, keys)
      raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless body.is_a?(Hash)
      raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless body["request_id"] == request_id

      results = body["results"]
      raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless results.is_a?(Array)
      raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" if results.length > keys.length

      seen = Set.new
      results.each do |item|
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless item.is_a?(Hash)
        key = item["key"].to_s
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless keys.include?(key)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" if seen.include?(key)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless item["decision"].is_a?(String)
        raise ::DiscourseAffiliate::PlatformClient::Error, "invalid_response" unless item["reason_code"].is_a?(String)

        seen << key
      end

      results
    end

    def validate_rewrite(raw)
      return nil unless raw.is_a?(Hash)

      href = raw["href"].to_s
      uri = URI.parse(href)
      return nil unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?

      click_url = raw["click_url"].presence
      if click_url.present?
        click_uri = URI.parse(click_url.to_s)
        return nil unless click_uri.is_a?(URI::HTTPS) && click_uri.host.present? && click_uri.userinfo.blank?
      end

      {
        href: href,
        external: raw["external"] == true,
        click_url: SiteSetting.affiliate_resolver_click_beacon_enabled ? click_url : nil,
        referrer_policy: %w[no-referrer origin].include?(raw["referrer_policy"].to_s) ? raw["referrer_policy"].to_s : "no-referrer",
      }
    rescue URI::InvalidURIError
      nil
    end

    def cohort_for(user)
      Digest::SHA256.hexdigest("discourse-affiliate-cohort:#{user.id}")[0, 8].to_i(16) % 100
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end

    def record_error(code, error)
      now = Time.zone.now
      ::DiscourseAffiliate::StateStore.write(
        last_resolve_error_at: now.iso8601(3),
        last_resolve_error_code: code.to_s.first(64),
      )
      ::DiscourseAffiliate::EventLog.record(
        event: :resolve_request,
        result: event_result(code),
        severity: :error,
        details: { http_status: error.respond_to?(:http_status) ? error.http_status : nil },
      )
      ::DiscourseAffiliate::SafeLog.warn("resolve_failed", error: error, http_status: error.respond_to?(:http_status) ? error.http_status : nil)
    end

    def event_result(code)
      return code.to_s if ::DiscourseAffiliate::EventLog::RESULTS.include?(code.to_s)
      return "server_error" if code.to_s == "http_error"
      return "invalid_response" if %w[invalid_json response_too_large].include?(code.to_s)

      "unknown"
    end
  end
end
