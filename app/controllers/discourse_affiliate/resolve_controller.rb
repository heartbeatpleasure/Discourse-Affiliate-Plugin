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
      post = Post.where(deleted_at: nil).find(params.require(:post_id).to_i)
      guardian.ensure_can_see!(post.topic)

      if post.topic.archetype == Archetype.private_message
        return render json: { observe_only: true, reason: "private_context", results: [] }
      end

      if SiteSetting.affiliate_resolver_local_staff_only && !current_user.staff?
        return render json: { observe_only: true, reason: "staff_only", results: [] }
      end

      links = normalize_links(params[:links])
      result = ::DiscourseAffiliate::Resolver.new.resolve(post: post, links: links, user: current_user)
      response.headers["Cache-Control"] = "no-store, private"
      response.headers["X-Content-Type-Options"] = "nosniff"
      render json: result
    rescue ActiveRecord::RecordNotFound
      raise Discourse::NotFound
    end

    private

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
