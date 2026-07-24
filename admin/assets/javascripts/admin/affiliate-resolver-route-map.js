export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("affiliateResolver", { path: "/affiliate-resolver" });
  },
};
