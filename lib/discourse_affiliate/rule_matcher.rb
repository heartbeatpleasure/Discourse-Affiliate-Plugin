# frozen_string_literal: true

require "uri"

module ::DiscourseAffiliate
  class RuleMatcher
    Match = Struct.new(:rule, :observe_only, keyword_init: true)

    def initialize(payload:, category_id:, staff:, cohort:)
      @payload = payload || {}
      @category_id = category_id&.to_i
      @staff = staff == true
      @cohort = cohort.to_i.clamp(0, 99)
    end

    def enabled?
      @payload["enabled"] == true
    end

    def match(url)
      return nil unless enabled?

      uri = URI.parse(url.to_s)
      return nil unless uri.is_a?(URI::HTTPS) && uri.host.present?
      return nil if uri.userinfo.present?

      rule = active_rules.find { |candidate| matches_rule?(candidate, uri) }
      return nil unless rule

      Match.new(
        rule: rule,
        observe_only: @payload["observe_only"] == true || rule["observe_only"] == true,
      )
    rescue URI::InvalidURIError
      nil
    end

    private

    def active_rules
      Array(@payload["rules"]).sort_by { |rule| -rule.fetch("priority", 0).to_i }
    end

    def matches_rule?(rule, uri)
      return false unless host_matches?(rule, uri.host.downcase)
      return false unless Array(rule["allowed_contexts"] || ["public_post"]).include?("public_post")
      return false if rule["staff_only"] == true && !@staff
      return false if @cohort >= rule.fetch("rollout_percentage", 0).to_i.clamp(0, 100)
      return false unless category_allowed?(rule)
      return false if path_excluded?(rule, uri.path.presence || "/")
      return false if disallowed_query?(rule, uri)

      true
    end

    def host_matches?(rule, host)
      configured = rule["host"].to_s.downcase
      return false if configured.blank?
      return true if host == configured

      rule["include_subdomains"] == true && host.end_with?(".#{configured}")
    end

    def category_allowed?(rule)
      allowed = Array(rule["allowed_category_ids"]).map(&:to_i)
      excluded = Array(rule["excluded_category_ids"]).map(&:to_i)
      return false if @category_id.present? && excluded.include?(@category_id)
      return true if allowed.empty?

      @category_id.present? && allowed.include?(@category_id)
    end

    def path_excluded?(rule, path)
      Array(rule["path_exclusions"]).any? do |prefix|
        normalized = prefix.to_s
        normalized.present? && path.start_with?(normalized)
      end
    end

    def disallowed_query?(rule, uri)
      pairs = URI.decode_www_form(uri.query.to_s)
      keys = pairs.map { |key, _value| key.downcase }
      denylist = Array(rule["query_denylist"]).map { |key| key.to_s.downcase }
      affiliate = Array(rule["affiliate_parameters"]).map { |key| key.to_s.downcase }
      allowlist = Array(rule["query_allowlist"]).map { |key| key.to_s.downcase }

      return true if (keys & denylist).any?
      return true if (keys & affiliate).any?
      return true if allowlist.any? && keys.any? { |key| !allowlist.include?(key) }

      false
    rescue ArgumentError
      true
    end
  end
end
