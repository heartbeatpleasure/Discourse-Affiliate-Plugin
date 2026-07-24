export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    // Intentionally empty. Affiliate Resolver uses the proven Heartrate-style
    // adminPlugins overview, Health, and Logs routes instead of nested show tabs.
  },
};
