# frozen_string_literal: true

require "digest"
require "set"
require "uri"
require "securerandom"

module ::DiscourseAffiliate
  class Resolver
    MAX_LINKS = 50
    ALLOWED_REL_VALUES = %w[nofollow ugc sponsored noreferrer noopener].freeze

    def resolve(source:, links:, user:)
      return response([], reason: "disabled") unless SiteSetting.affiliate_resolver_enabled
      return response([], reason: "staff_only") if SiteSetting.affiliate_resolver_local_staff_only && !user.staff?

      cooked_urls = ::DiscourseAffiliate::PostLinkExtractor.new(source.cooked).eligible_urls
      browser_links = normalized_browser_links(links, cooked_urls)
      overrides = ::DiscourseAffiliate::ModeratorOverrideStore.new(source.record)

      if overrides.source_disabled?
        disabled_results = browser_links.map do |link|
          local_result(link[:key], "moderator_disabled")
        end
        return response(disabled_results, reason: "moderator_disabled", source_disabled: true)
      end

      cache = ::DiscourseAffiliate::RulesCache.current
      return response([], reason: "rules_unavailable") if cache.blank?

      payload = cache.fetch("payload")
      cohort = cohort_for(user)
      matcher = ::DiscourseAffiliate::RuleMatcher.new(
        payload: payload,
        context_kind: source.kind,
        category_id: source.category_id,
        staff: user.staff?,
        cohort: cohort,
      )
      return response([], reason: "platform_disabled") unless matcher.enabled?

      candidates = []
      matches = {}
      local_results = []

      browser_links.each do |link|
        matched = matcher.match(link[:url])
        next unless matched

        if overrides.link_excluded?(link[:url])
          local_results << local_result(link[:key], "moderator_excluded")
          next
        end

        candidates << link
        matches[link[:key]] = matched
      end

      if candidates.empty?
        reason = local_results.any? ? "moderator_excluded" : "no_eligible_links"
        return response(local_results, reason: reason)
      end

      request_id = SecureRandom.uuid
      platform_payload = {
        request_id: request_id,
        plugin_version: ::DiscourseAffiliate::PLUGIN_VERSION,
        context: {
          kind: source.kind,
          category_id: source.category_id,
          staff: user.staff?,
          cohort: cohort,
          source_ref_hash: ::DiscourseAffiliate::SourceReference.hash(source.source_type, source.source_id),
        }.compact,
        links: candidates,
      }

      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = ::DiscourseAffiliate::PlatformClient.new.resolve(platform_payload)
      parsed = validate_response(result.fetch(:body), request_id, candidates.map { |candidate| candidate[:key] })
      local_observe_only = SiteSetting.affiliate_resolver_local_observe_only

      platform_results = parsed.map do |item|
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

      ordered_results = order_results(browser_links, platform_results + local_results)
      latency_ms = elapsed_ms(started_at)
      now = Time.zone.now
      ::DiscourseAffiliate::StateStore.write(
        last_resolve_success_at: now.iso8601(3),
        last_resolve_error_code: nil,
        last_resolve_latency_ms: latency_ms,
        last_resolve_link_count: candidates.length,
        last_resolve_result_count: ordered_results.length,
      )
      if SiteSetting.affiliate_resolver_debug_logging_enabled
        ::DiscourseAffiliate::EventLog.record(
          event: :resolve_request,
          result: :success,
          details: {
            latency_ms: latency_ms,
            link_count: candidates.length,
            result_count: ordered_results.length,
            http_status: result[:http_status],
            context_kind: source.kind,
          },
        )
      end

      response(ordered_results, reason: "success")
    rescue ::DiscourseAffiliate::PlatformClient::Error => error
      record_error(error.code, error)
      response([], reason: "platform_unavailable")
    rescue StandardError => error
      record_error("invalid_response", error)
      response([], reason: "platform_unavailable")
    end

    private

    def normalized_browser_links(links, cooked_urls)
      seen_keys = Set.new

      Array(links).first(MAX_LINKS).filter_map do |link|
        key = link[:key].to_s
        normalized_url = ::DiscourseAffiliate::PostLinkExtractor.normalize_url(link[:url])
        next unless key.match?(/\A[A-Za-z0-9_-]{1,64}\z/)
        next if seen_keys.include?(key)
        next if normalized_url.blank? || normalized_url.bytesize > 4096
        next unless cooked_urls.include?(normalized_url)

        seen_keys << key
        { key: key, url: normalized_url }
      end
    end

    def local_result(key, reason_code)
      {
        key: key,
        decision: "skipped",
        reason_code: reason_code,
        applied: false,
        rewrite: nil,
      }
    end

    def order_results(browser_links, results)
      by_key = results.index_by { |item| item[:key] }
      browser_links.filter_map { |link| by_key[link[:key]] }
    end

    def response(results, reason:, source_disabled: false)
      {
        observe_only: SiteSetting.affiliate_resolver_local_observe_only,
        reason: reason,
        source_disabled: source_disabled,
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

      rel_values = raw["rel"].to_s.split(/\s+/) & ALLOWED_REL_VALUES

      {
        href: href,
        external: raw["external"] == true,
        click_url: SiteSetting.affiliate_resolver_click_beacon_enabled ? click_url : nil,
        referrer_policy: %w[no-referrer origin].include?(raw["referrer_policy"].to_s) ? raw["referrer_policy"].to_s : "no-referrer",
        rel: rel_values.join(" "),
        merchant: raw["merchant"].to_s.first(120).presence,
        disclosure: raw["disclosure"].to_s.first(500).presence,
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
