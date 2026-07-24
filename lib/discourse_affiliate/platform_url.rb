# frozen_string_literal: true

require "ipaddr"
require "uri"

module ::DiscourseAffiliate
  class PlatformUrl
    class Invalid < StandardError
    end

    BLOCKED_HOSTS = %w[localhost localhost.localdomain].freeze
    BLOCKED_SUFFIXES = %w[.local .internal .localhost].freeze

    class << self
      def base
        raw = SiteSetting.affiliate_resolver_platform_base_url.to_s.strip
        raise Invalid, "missing" if raw.blank?

        uri = URI.parse(raw)
        validate!(uri)
        uri.path = ""
        uri
      rescue URI::InvalidURIError
        raise Invalid, "invalid"
      end

      def endpoint(path)
        uri = base.dup
        uri.path = path
        uri
      end

      def configured?
        base
        true
      rescue Invalid
        false
      end

      private

      def validate!(uri)
        raise Invalid, "https_required" unless uri.is_a?(URI::HTTPS)
        raise Invalid, "host_missing" if uri.host.blank?
        raise Invalid, "credentials_not_allowed" if uri.userinfo.present?
        raise Invalid, "query_not_allowed" if uri.query.present?
        raise Invalid, "fragment_not_allowed" if uri.fragment.present?
        raise Invalid, "path_not_allowed" unless uri.path.blank? || uri.path == "/"

        host = uri.host.downcase
        raise Invalid, "ip_literal_not_allowed" if host.include?(":") || host.include?("[") || host.include?("]")
        raise Invalid, "host_not_allowed" if BLOCKED_HOSTS.include?(host)
        raise Invalid, "host_not_allowed" if BLOCKED_SUFFIXES.any? { |suffix| host.end_with?(suffix) }

        begin
          address = IPAddr.new(host)
          raise Invalid, "ip_literal_not_allowed" if address
        rescue IPAddr::InvalidAddressError
          nil
        end
      end
    end
  end
end
