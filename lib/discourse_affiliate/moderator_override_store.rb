# frozen_string_literal: true

require "digest"
require "json"

module ::DiscourseAffiliate
  class ModeratorOverrideStore
    SOURCE_DISABLED_FIELD = "affiliate_resolver_source_disabled"
    EXCLUDED_LINK_HASHES_FIELD = "affiliate_resolver_excluded_link_hashes"
    MAX_EXCLUDED_LINKS = 100

    def initialize(source)
      @source = source
    end

    def source_disabled?
      ActiveModel::Type::Boolean.new.cast(@source.custom_fields[SOURCE_DISABLED_FIELD])
    end

    def disable_source!
      write_field(SOURCE_DISABLED_FIELD, true)
    end

    def enable_source!
      delete_field(SOURCE_DISABLED_FIELD)
    end

    def link_excluded?(url)
      hash = self.class.url_hash(url)
      hash.present? && excluded_hashes.include?(hash)
    end

    def exclude_link!(url)
      hash = self.class.url_hash(url)
      raise ArgumentError, "invalid_url" if hash.blank?

      hashes = excluded_hashes
      hashes << hash unless hashes.include?(hash)
      raise ArgumentError, "too_many_exclusions" if hashes.length > MAX_EXCLUDED_LINKS

      write_field(EXCLUDED_LINK_HASHES_FIELD, hashes.sort)
    end

    def include_link!(url)
      hash = self.class.url_hash(url)
      raise ArgumentError, "invalid_url" if hash.blank?

      hashes = excluded_hashes - [hash]
      if hashes.empty?
        delete_field(EXCLUDED_LINK_HASHES_FIELD)
      else
        write_field(EXCLUDED_LINK_HASHES_FIELD, hashes.sort)
      end
    end

    def self.url_hash(url)
      normalized = ::DiscourseAffiliate::PostLinkExtractor.normalize_url(url)
      Digest::SHA256.hexdigest(normalized) if normalized.present?
    end

    private

    def excluded_hashes
      raw = @source.custom_fields[EXCLUDED_LINK_HASHES_FIELD]
      parsed = raw.is_a?(String) ? JSON.parse(raw.presence || "[]") : raw

      Array(parsed)
        .map(&:to_s)
        .select { |value| value.match?(/\A[a-f0-9]{64}\z/) }
        .uniq
        .first(MAX_EXCLUDED_LINKS)
    rescue JSON::ParserError
      []
    end

    def write_field(key, value)
      @source.custom_fields[key] = value
      @source.save_custom_fields
    end

    def delete_field(key)
      @source.custom_fields.delete(key)
      @source.save_custom_fields
    end
  end
end
