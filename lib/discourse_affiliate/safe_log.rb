# frozen_string_literal: true

module ::DiscourseAffiliate
  class SafeLog
    class << self
      def info(event, **fields)
        Rails.logger.info(format(event, fields))
      rescue StandardError
        nil
      end

      def warn(event, error: nil, **fields)
        safe_fields = fields.merge(error_class: error&.class&.name)
        Rails.logger.warn(format(event, safe_fields))
      rescue StandardError
        nil
      end

      private

      def format(event, fields)
        sanitized = fields.each_with_object({}) do |(key, value), output|
          next unless %i[
            error_class
            http_status
            latency_ms
            link_count
            result_count
            rule_count
            reason_code
          ].include?(key.to_sym)

          output[key] = value
        end

        "[affiliate_resolver] #{event} #{sanitized.to_json}"
      end
    end
  end
end
