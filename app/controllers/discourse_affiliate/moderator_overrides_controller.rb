# frozen_string_literal: true

module ::DiscourseAffiliate
  class ModeratorOverridesController < ::ApplicationController
    requires_plugin ::DiscourseAffiliate::PLUGIN_NAME
    requires_login
    before_action :ensure_staff

    OPERATIONS = %w[disable_source enable_source exclude_link include_link].freeze

    def update
      raise Discourse::InvalidAccess unless SiteSetting.affiliate_resolver_moderator_controls_enabled

      rate_limit!
      source = load_source
      store = ::DiscourseAffiliate::ModeratorOverrideStore.new(source)
      operation = params.require(:operation).to_s
      raise Discourse::InvalidParameters, "Invalid moderator operation" unless OPERATIONS.include?(operation)

      case operation
      when "disable_source"
        store.disable_source!
      when "enable_source"
        store.enable_source!
      when "exclude_link"
        store.exclude_link!(params.require(:url))
      when "include_link"
        store.include_link!(params.require(:url))
      end

      url = params[:url].presence
      log_override(source, operation, url)
      response.headers["Cache-Control"] = "no-store, private"
      response.headers["X-Content-Type-Options"] = "nosniff"
      render json: {
        source_disabled: store.source_disabled?,
        link_excluded: url.present? ? store.link_excluded?(url) : nil,
      }
    rescue ActiveRecord::RecordNotFound
      raise Discourse::NotFound
    rescue ArgumentError
      raise Discourse::InvalidParameters, "Invalid affiliate URL"
    end

    private

    def ensure_staff
      raise Discourse::InvalidAccess unless current_user&.staff?
    end

    def load_source
      source_type = params.require(:source_type).to_s
      source_id = params.require(:source_id).to_i

      case source_type
      when "post"
        post = Post.where(deleted_at: nil).find(source_id)
        guardian.ensure_can_see!(post.topic)
        post
      when "chat"
        raise Discourse::NotFound unless defined?(::Chat::Message)

        message = ::Chat::Message.where(deleted_at: nil).includes(:chat_channel).find(source_id)
        unless guardian.respond_to?(:can_see_chat_message?) && guardian.can_see_chat_message?(message)
          raise Discourse::InvalidAccess
        end
        message
      else
        raise Discourse::InvalidParameters, "Invalid source type"
      end
    end

    def log_override(source, operation, url)
      details = {
        source_type: params[:source_type].to_s,
        source_id: source.id,
        operation: operation,
      }
      link_hash = ::DiscourseAffiliate::ModeratorOverrideStore.url_hash(url) if url.present?
      details[:link_hash] = link_hash if link_hash.present?

      StaffActionLogger.new(current_user).log_custom("affiliate_resolver_override", details)
    rescue StandardError => error
      ::DiscourseAffiliate::SafeLog.warn("moderator_override_audit_failed", error: error)
    end

    def rate_limit!
      RateLimiter.new(current_user, "affiliate_resolver_moderator_override", 30, 1.minute).performed!
    end
  end
end
