# frozen_string_literal: true

module ::DiscourseAffiliate
  class AdminHealthController < ::Admin::AdminController
    requires_plugin ::DiscourseAffiliate::PLUGIN_NAME

    def index
      response.headers["Cache-Control"] = "no-store"
      render_json_dump(::DiscourseAffiliate::AdminHealth.summary)
    end

    def refresh
      ::DiscourseAffiliate::RulesCache.refresh!
      response.headers["Cache-Control"] = "no-store"
      render_json_dump(::DiscourseAffiliate::AdminHealth.summary)
    end
  end
end
