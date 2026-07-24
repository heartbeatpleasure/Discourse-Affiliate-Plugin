# frozen_string_literal: true

require "openssl"

module ::DiscourseAffiliate
  class SourceReference
    class << self
      def hash(post_id)
        OpenSSL::HMAC.hexdigest(
          "SHA256",
          Rails.application.secret_key_base,
          "discourse-affiliate:post:#{post_id.to_i}",
        )
      end
    end
  end
end
