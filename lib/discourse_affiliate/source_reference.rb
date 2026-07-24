# frozen_string_literal: true

require "openssl"

module ::DiscourseAffiliate
  class SourceReference
    ALLOWED_TYPES = %w[post chat].freeze

    class << self
      # Backwards compatible: hash(post_id) still produces a post reference.
      def hash(source_type_or_id, source_id = nil)
        source_type, id = source_id.nil? ? ["post", source_type_or_id] : [source_type_or_id, source_id]
        normalized_type = source_type.to_s
        raise ArgumentError, "invalid_source_type" unless ALLOWED_TYPES.include?(normalized_type)

        OpenSSL::HMAC.hexdigest(
          "SHA256",
          Rails.application.secret_key_base,
          "discourse-affiliate:#{normalized_type}:#{id.to_i}",
        )
      end
    end
  end
end
