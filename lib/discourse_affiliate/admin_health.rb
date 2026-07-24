# frozen_string_literal: true

module ::DiscourseAffiliate
  class AdminHealth
    class << self
      def summary
        state = ::DiscourseAffiliate::StateStore.read
        cache = ::DiscourseAffiliate::RulesCache.cached
        configuration = configuration_payload
        cache_payload = cache_payload(cache, state)

        {
          generated_at: Time.zone.now.iso8601(3),
          overall: overall(configuration, cache_payload, state),
          configuration: configuration,
          cache: cache_payload,
          activity: {
            last_rules_success_at: state["last_rules_success_at"],
            last_rules_error_at: state["last_rules_error_at"],
            last_rules_error_code: state["last_rules_error_code"],
            last_rules_latency_ms: state["last_rules_latency_ms"],
            last_resolve_success_at: state["last_resolve_success_at"],
            last_resolve_error_at: state["last_resolve_error_at"],
            last_resolve_error_code: state["last_resolve_error_code"],
            last_resolve_latency_ms: state["last_resolve_latency_ms"],
          },
        }
      end

      private

      def configuration_payload
        platform_url = ::DiscourseAffiliate::PlatformUrl.status

        {
          plugin_enabled: SiteSetting.affiliate_resolver_enabled,
          local_observe_only: SiteSetting.affiliate_resolver_local_observe_only,
          local_staff_only: SiteSetting.affiliate_resolver_local_staff_only,
          platform_url_configured: platform_url[:configured],
          platform_url_error_code: platform_url[:error_code],
          platform_url_scheme: platform_url[:scheme],
          platform_url_secure: platform_url[:secure],
          api_token_configured: SiteSetting.affiliate_resolver_platform_api_token.to_s.length >= 32,
          request_timeout_ms: SiteSetting.affiliate_resolver_request_timeout_ms.to_i.clamp(100, 300),
          click_beacon_enabled: SiteSetting.affiliate_resolver_click_beacon_enabled,
        }
      end

      def cache_payload(cache, state)
        payload = cache&.dig("payload") || {}
        {
          available: cache.present?,
          enabled: payload["enabled"] == true,
          platform_observe_only: payload["observe_only"] == true,
          version: payload["version"].presence || state["cache_version"],
          active_rules: Array(payload["rules"]).length,
          fetched_at: cache&.dig("fetched_at") || state["cache_fetched_at"],
          expires_at: cache&.dig("expires_at") || state["cache_expires_at"],
        }
      end

      def overall(configuration, cache, state)
        return { state: "inactive", severity: "info" } unless configuration[:plugin_enabled]

        unless configuration[:platform_url_configured] && configuration[:api_token_configured]
          return { state: "unhealthy", severity: "critical" }
        end

        return { state: "warning", severity: "warning" } unless cache[:available]
        return { state: "warning", severity: "warning" } unless cache[:enabled]

        if state["last_rules_error_at"].present? && state["last_rules_success_at"].blank?
          return { state: "warning", severity: "warning" }
        end

        { state: "ready", severity: "ok" }
      end
    end
  end
end
