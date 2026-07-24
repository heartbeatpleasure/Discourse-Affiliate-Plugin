# frozen_string_literal: true

require "json"
require "net/http"
require "openssl"

module ::DiscourseAffiliate
  class PlatformClient
    class Error < StandardError
      attr_reader :code, :http_status

      def initialize(code, http_status: nil)
        @code = code.to_s
        @http_status = http_status
        super(@code)
      end
    end

    MAX_RULES_BYTES = 512.kilobytes
    MAX_RESOLVE_BYTES = 1.megabyte

    def fetch_rules(etag: nil)
      request = Net::HTTP::Get.new(::DiscourseAffiliate::PlatformUrl.endpoint("/api/v1/discourse/rules"))
      request["If-None-Match"] = etag if etag.present?
      perform(request, max_bytes: MAX_RULES_BYTES, allow_not_modified: true)
    end

    def resolve(payload)
      request = Net::HTTP::Post.new(::DiscourseAffiliate::PlatformUrl.endpoint("/api/v1/discourse/resolve"))
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)
      perform(request, max_bytes: MAX_RESOLVE_BYTES)
    end

    private

    def perform(request, max_bytes:, allow_not_modified: false)
      token = SiteSetting.affiliate_resolver_platform_api_token.to_s
      raise Error, "token_missing" if token.length < 32

      request["Accept"] = "application/json"
      request["Authorization"] = "Bearer #{token}"
      request["User-Agent"] = "Discourse-Affiliate-Plugin/#{::DiscourseAffiliate::PLUGIN_VERSION}"

      timeout_seconds = SiteSetting.affiliate_resolver_request_timeout_ms.to_i.clamp(100, 300) / 1000.0
      uri = request.uri
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: timeout_seconds,
        read_timeout: timeout_seconds,
        write_timeout: timeout_seconds,
        verify_mode: OpenSSL::SSL::VERIFY_PEER,
      ) { |http| http.request(request) }

      latency_ms = elapsed_ms(started_at)

      if allow_not_modified && response.is_a?(Net::HTTPNotModified)
        return { status: :not_modified, etag: response["ETag"], latency_ms: latency_ms }
      end

      case response
      when Net::HTTPSuccess
        body = response.body.to_s
        raise Error.new("response_too_large", http_status: response.code.to_i) if body.bytesize > max_bytes

        parsed = JSON.parse(body)
        raise Error.new("invalid_response", http_status: response.code.to_i) unless parsed.is_a?(Hash)

        {
          status: :success,
          body: parsed,
          etag: response["ETag"],
          latency_ms: latency_ms,
          http_status: response.code.to_i,
        }
      when Net::HTTPUnauthorized
        raise Error.new("unauthorized", http_status: 401)
      when Net::HTTPForbidden
        raise Error.new("forbidden", http_status: 403)
      when Net::HTTPTooManyRequests
        raise Error.new("rate_limited", http_status: 429)
      else
        raise Error.new("http_error", http_status: response.code.to_i)
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout
      raise Error, "timeout"
    rescue JSON::ParserError
      raise Error, "invalid_json"
    rescue SocketError, OpenSSL::SSL::SSLError, IOError, SystemCallError
      raise Error, "unavailable"
    end

    def elapsed_ms(started_at)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
    end
  end
end
