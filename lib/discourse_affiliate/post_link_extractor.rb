# frozen_string_literal: true

require "nokogiri"
require "set"
require "uri"

module ::DiscourseAffiliate
  class PostLinkExtractor
    EXCLUDED_ANCESTOR_SELECTORS = [
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
    ONEBOX_SELECTORS = [
      "aside.onebox[data-onebox-src]",
      ".onebox[data-onebox-src]",
    ].freeze
    ONEBOX_SELECTOR = ONEBOX_SELECTORS.join(", ")

    def initialize(cooked)
      @document = Nokogiri::HTML5.fragment(cooked.to_s)
    end

    def eligible_urls
      @document
        .css("a[href], #{ONEBOX_SELECTOR}")
        .each_with_object(Set.new) do |node, output|
          if node["data-onebox-src"].present?
            next if excluded_container?(node)

            normalized = self.class.normalize_url(node["data-onebox-src"])
            output << normalized if normalized.present?
            next
          end

          # Onebox links are validated against the server-generated
          # data-onebox-src value above. Ignore author, metadata, and related
          # links contained inside the preview itself.
          next if onebox_ancestor?(node)
          next if excluded?(node)

          normalized = self.class.normalize_url(node["href"])
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

      excluded_container?(anchor)
    end

    def onebox_ancestor?(node)
      ONEBOX_SELECTORS.any? { |selector| node.ancestors(selector).any? }
    end

    def excluded_container?(node)
      EXCLUDED_ANCESTOR_SELECTORS.any? { |selector| node.ancestors(selector).any? }
    end
  end
end
