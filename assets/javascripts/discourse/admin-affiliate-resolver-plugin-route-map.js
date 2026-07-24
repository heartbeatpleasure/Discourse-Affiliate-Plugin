export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("affiliate-resolver-health", { path: "health" });
    this.route("affiliate-resolver-logs", { path: "logs" });
  },
};
