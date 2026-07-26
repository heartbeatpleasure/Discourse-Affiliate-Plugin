# frozen_string_literal: true

module ::DiscourseAffiliate
  class ResolveController < ::ApplicationController
    requires_plugin ::DiscourseAffiliate::PLUGIN_NAME
    requires_login

    def create
      unless SiteSetting.affiliate_resolver_enabled
        return render json: { observe_only: true, reason: "disabled", results: [] }
      end

      rate_limit!
      source = source_context

      unless context_enabled?(source.kind)
        return render json: {
          observe_only: true,
          reason: "context_disabled",
          source_disabled: false,
          results: [],
        }
      end

      if SiteSetting.affiliate_resolver_local_staff_only && !current_user.staff?
        return render json: {
          observe_only: true,
          reason: "staff_only",
          source_disabled: false,
          results: [],
        }
      end

      links = normalize_links(params[:links])
      result = ::DiscourseAffiliate::Resolver.new.resolve(source: source, links: links, user: current_user)
      response.headers["Cache-Control"] = "no-store, private"
      response.headers["X-Content-Type-Options"] = "nosniff"
      render json: result
    rescue ActiveRecord::RecordNotFound
      raise Discourse::NotFound
    end

    private

    def source_context
      post_id = params[:post_id].presence
      chat_message_id = params[:chat_message_id].presence
      raise Discourse::InvalidParameters, "Exactly one source identifier is required" if post_id.present? == chat_message_id.present?

      if post_id.present?
        post = Post.where(deleted_at: nil).find(post_id.to_i)
        guardian.ensure_can_see!(post.topic)
        return ::DiscourseAffiliate::SourceContext.from_post(post)
      end

      raise Discourse::NotFound unless defined?(::Chat::Message)

      message = ::Chat::Message.where(deleted_at: nil).includes(:chat_channel).find(chat_message_id.to_i)
      unless guardian.respond_to?(:can_see_chat_message?) && guardian.can_see_chat_message?(message)
        raise Discourse::InvalidAccess
      end

      ::DiscourseAffiliate::SourceContext.from_chat(message)
    end

    def context_enabled?(kind)
      case kind
      when "public_post"
        SiteSetting.affiliate_resolver_public_posts_enabled
      when "private_message"
        SiteSetting.affiliate_resolver_personal_messages_enabled
      when "chat"
        SiteSetting.affiliate_resolver_chat_enabled
      else
        false
      end
    end

    def rate_limit!
      RateLimiter.new(current_user, "affiliate_resolver", 60, 1.minute).performed!
    end

    def normalize_links(raw)
      entries =
        if raw.is_a?(Array)
          raw
        else
          values = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
          return [] unless values.is_a?(Hash)

          if values.key?(:key) || values.key?("key") || values.key?(:url) || values.key?("url")
            [values]
          else
            values.values
          end
        end

      entries.first(::DiscourseAffiliate::Resolver::MAX_LINKS).filter_map do |entry|
        values = entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry
        next unless values.respond_to?(:[])

        { key: values[:key] || values["key"], url: values[:url] || values["url"] }
      end
    end
  end
end
