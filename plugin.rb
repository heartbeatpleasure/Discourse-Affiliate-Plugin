# frozen_string_literal: true

# name: Discourse-Affiliate-Resolver
# about: Privacy-safe affiliate link resolution for Discourse posts, personal messages, and Chat.
# version: 0.1.7
# authors: Chris
# url: https://github.com/xxxxxx/Discourse-Affiliate-Plugin

add_admin_route "admin.affiliate_resolver.title", "affiliateResolver"

enabled_site_setting :affiliate_resolver_enabled

register_asset "stylesheets/common/affiliate-resolver.scss"

module ::DiscourseAffiliate
  PLUGIN_NAME = "Discourse-Affiliate-Resolver"
  PLUGIN_VERSION = "0.1.7"
end

after_initialize do
  begin
    Rails.application.config.filter_parameters |= [
      :affiliate_platform_api_token,
      :authorization,
      :token,
      :api_token,
    ]
  rescue StandardError
    # Keep boot resilient when filter configuration is unavailable.
  end

  require_relative "lib/discourse_affiliate/safe_log"
  require_relative "lib/discourse_affiliate/event_log"
  require_relative "lib/discourse_affiliate/state_store"
  require_relative "lib/discourse_affiliate/platform_url"
  require_relative "lib/discourse_affiliate/platform_client"
  require_relative "lib/discourse_affiliate/rules_cache"
  require_relative "lib/discourse_affiliate/rule_matcher"
  require_relative "lib/discourse_affiliate/source_reference"
  require_relative "lib/discourse_affiliate/post_link_extractor"
  require_relative "lib/discourse_affiliate/source_context"
  require_relative "lib/discourse_affiliate/moderator_override_store"
  require_relative "lib/discourse_affiliate/resolver"
  require_relative "lib/discourse_affiliate/admin_health"

  [::Post, (defined?(::Chat::Message) ? ::Chat::Message : nil)].compact.each do |model|
    model.register_custom_field_type(
      ::DiscourseAffiliate::ModeratorOverrideStore::SOURCE_DISABLED_FIELD,
      :boolean,
    )
    model.register_custom_field_type(
      ::DiscourseAffiliate::ModeratorOverrideStore::EXCLUDED_LINK_HASHES_FIELD,
      :json,
      max_length: 10_000,
    )
  end

  require_dependency File.expand_path(
    "app/controllers/discourse_affiliate/resolve_controller.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/controllers/discourse_affiliate/moderator_overrides_controller.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/controllers/discourse_affiliate/admin_health_controller.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/controllers/discourse_affiliate/admin_logs_controller.rb",
    __dir__,
  )
  require_dependency File.expand_path(
    "app/jobs/scheduled/discourse_affiliate/refresh_rules.rb",
    __dir__,
  )

  on(:site_setting_changed) do |name, _old_value, _new_value|
    next unless %i[
      affiliate_resolver_enabled
      affiliate_resolver_platform_base_url
      affiliate_resolver_platform_api_token
      affiliate_resolver_local_observe_only
      affiliate_resolver_local_staff_only
      affiliate_resolver_personal_messages_enabled
      affiliate_resolver_chat_enabled
      affiliate_resolver_request_timeout_ms
    ].include?(name.to_sym)

    ::DiscourseAffiliate::RulesCache.clear!
    ::DiscourseAffiliate::StateStore.record_configuration_change(name)
  end

  Discourse::Application.routes.append do
    post "/affiliate-resolver/resolve" => "discourse_affiliate/resolve#create",
         defaults: { format: :json }
    post "/affiliate-resolver/moderator-override" =>
           "discourse_affiliate/moderator_overrides#update",
         defaults: { format: :json }

    # Match the proven Heartrate admin pattern: a dedicated overview plus
    # separate Health and Logs pages under adminPlugins.
    get "/admin/plugins/affiliate-resolver" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/affiliate-resolver-health" => "admin/plugins#index",
        constraints: AdminConstraint.new
    get "/admin/plugins/affiliate-resolver-logs" => "admin/plugins#index",
        constraints: AdminConstraint.new

    get "/admin/plugins/affiliate-resolver/health.json" =>
          "discourse_affiliate/admin_health#index",
        defaults: { format: :json },
        constraints: AdminConstraint.new
    post "/admin/plugins/affiliate-resolver/health/refresh.json" =>
           "discourse_affiliate/admin_health#refresh",
         defaults: { format: :json },
         constraints: AdminConstraint.new
    get "/admin/plugins/affiliate-resolver/logs.json" => "discourse_affiliate/admin_logs#index",
        defaults: { format: :json },
        constraints: AdminConstraint.new
  end
end
