# frozen_string_literal: true

require "json"

module ::DiscourseAffiliate
  class StateStore
    KEY = "discourse_affiliate:state:v1"
    RETENTION_SECONDS = 30.days.to_i
    ALLOWED_KEYS = %w[
      cache_version
      cache_rule_count
      cache_fetched_at
      cache_expires_at
      last_rules_success_at
      last_rules_error_at
      last_rules_error_code
      last_rules_latency_ms
      last_resolve_success_at
      last_resolve_error_at
      last_resolve_error_code
      last_resolve_latency_ms
      last_resolve_link_count
      last_resolve_result_count
      last_configuration_change_at
      last_configuration_setting
    ].freeze

    class << self
      def read
        raw = Discourse.redis.get(KEY)
        raw.present? ? JSON.parse(raw) : {}
      rescue JSON::ParserError, StandardError
        {}
      end

      def write(values)
        current = read
        values.each do |key, value|
          normalized_key = key.to_s
          current[normalized_key] = value if ALLOWED_KEYS.include?(normalized_key)
        end
        Discourse.redis.setex(KEY, RETENTION_SECONDS, JSON.generate(current))
        true
      rescue StandardError => error
        ::DiscourseAffiliate::SafeLog.warn("state_write_failed", error: error)
        false
      end

      def record_configuration_change(name)
        write(
          last_configuration_change_at: Time.zone.now.iso8601(3),
          last_configuration_setting: name.to_s,
        )
        ::DiscourseAffiliate::EventLog.record(
          event: :configuration,
          result: :success,
          details: { setting: name.to_s },
        )
      end
    end
  end
end
