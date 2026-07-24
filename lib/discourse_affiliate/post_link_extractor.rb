# frozen_string_literal: true

require "nokogiri"
require "set"
require "uri"

module ::DiscourseAffiliate
  class PostLinkExtractor
    EXCLUDED_ANCESTOR_SELECTORS = [
      "aside.onebox",
      ".onebox",
      "blockquote",
      ".quote",
    ].freeze
    EXCLUDED_LINK_CLASSES = %w[
      mention
      mention-group
      hashtag-cooked
      lightbox
      attachment
      onebox
    ].freeze

    def initialize(cooked)
      @document = Nokogiri::HTML5.fragment(cooked.to_s)
    end

    def eligible_urls
      @document.css("a[href]").each_with_object(Set.new) do |anchor, output|
        next if excluded?(anchor)

        normalized = self.class.normalize_url(anchor["href"])
        output << normalized if normalized.present?
      end
    end

    def self.normalize_url(value)
      uri = URI.parse(value.to_s.strip)
      return nil unless uri.is_a?(URI::HTTPS)
      return nil if uri.host.blank? || uri.userinfo.present?
      return nil if internal_host?(uri.host)

      host = uri.host.downcase
      port = uri.port == 443 ? "" : ":#{uri.port}"
      path = uri.path.presence || "/"
      query = uri.query.present? ? "?#{uri.query}" : ""
      fragment = uri.fragment.present? ? "##{uri.fragment}" : ""
      "https://#{host}#{port}#{path}#{query}#{fragment}"
    rescue URI::InvalidURIError
      nil
    end

    def self.internal_host?(host)
      base = URI.parse(Discourse.base_url)
      host.casecmp?(base.host.to_s)
    rescue URI::InvalidURIError
      true
    end

    private

    def excluded?(anchor)
      classes = anchor["class"].to_s.split
      return true if (classes & EXCLUDED_LINK_CLASSES).any?

      EXCLUDED_ANCESTOR_SELECTORS.any? { |selector| anchor.ancestors(selector).any? }
    end
  end
end
