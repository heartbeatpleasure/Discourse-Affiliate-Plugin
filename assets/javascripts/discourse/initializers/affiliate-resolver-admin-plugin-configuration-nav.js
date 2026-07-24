import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "affiliate-resolver";

export default {
  name: "affiliate-resolver-admin-plugin-configuration-nav",

  initialize(container) {
    const currentUser = container.lookup("service:current-user");

    if (!currentUser?.admin) {
      return;
    }

    withPluginApi((api) => {
      api.addAdminPluginConfigurationNav(PLUGIN_ID, [
        {
          label: "affiliate_resolver.health.short_title",
          route: "adminPlugins.show.affiliate-resolver-health",
          description: "affiliate_resolver.health.description",
        },
        {
          label: "affiliate_resolver.logs.short_title",
          route: "adminPlugins.show.affiliate-resolver-logs",
          description: "affiliate_resolver.logs.description",
        },
      ]);
    });
  },
};
