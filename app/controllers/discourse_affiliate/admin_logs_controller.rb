# frozen_string_literal: true

module ::DiscourseAffiliate
  class AdminLogsController < ::Admin::AdminController
    requires_plugin ::DiscourseAffiliate::PLUGIN_NAME

    def index
      response.headers["Cache-Control"] = "no-store"
      render_json_dump(
        generated_at: Time.zone.now.iso8601(3),
        events: ::DiscourseAffiliate::EventLog.recent(limit: params[:limit]),
      )
    end
  end
end
