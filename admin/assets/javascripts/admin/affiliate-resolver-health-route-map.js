export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("affiliateResolverHealth", { path: "/affiliate-resolver-health" });
  },
};
