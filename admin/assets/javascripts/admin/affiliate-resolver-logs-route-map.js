export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("affiliateResolverLogs", { path: "/affiliate-resolver-logs" });
  },
};
