# frozen_string_literal: true

module ::Jobs
  module DiscourseAffiliate
    class RefreshRules < ::Jobs::Scheduled
      every 5.minutes

      def execute(_args)
        return unless SiteSetting.affiliate_resolver_enabled

        ::DiscourseAffiliate::RulesCache.refresh!
      end
    end
  end
end
