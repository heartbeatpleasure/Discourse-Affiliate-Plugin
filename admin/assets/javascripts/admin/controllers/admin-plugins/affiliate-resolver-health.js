import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

function formatDate(value) {
  if (!value) {
    return i18n("admin.affiliate_resolver.health.not_available");
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? i18n("admin.affiliate_resolver.health.not_available")
    : new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "medium" }).format(date);
}

function yesNo(value) {
  return value
    ? i18n("admin.affiliate_resolver.health.yes")
    : i18n("admin.affiliate_resolver.health.no");
}

function extractError(error) {
  return error?.jqXHR?.responseJSON?.errors?.[0] || error?.message || i18n("admin.affiliate_resolver.health.load_error");
}

export default class AdminPluginsAffiliateResolverHealthController extends Controller {
  @tracked data = null;
  @tracked isLoading = false;
  @tracked isRefreshingRules = false;
  @tracked error = null;

  resetState() {
    this.data = null;
    this.error = null;
  }

  @action
  async loadHealth() {
    if (this.isLoading) return;
    this.isLoading = true;
    this.error = null;
    try {
      this.data = await ajax("/admin/plugins/affiliate-resolver/health.json");
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  async refreshRules() {
    if (this.isRefreshingRules) return;
    this.isRefreshingRules = true;
    this.error = null;
    try {
      this.data = await ajax("/admin/plugins/affiliate-resolver/health/refresh.json", { type: "POST" });
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.isRefreshingRules = false;
    }
  }

  get generatedAt() { return formatDate(this.data?.generated_at); }
  get overallState() { return this.data?.overall?.state || "inactive"; }
  get overallLabel() { return i18n(`admin.affiliate_resolver.health.state.${this.overallState}`); }
  get configurationRows() {
    const c = this.data?.configuration || {};
    return [
      ["plugin_enabled", yesNo(c.plugin_enabled)],
      ["local_observe_only", yesNo(c.local_observe_only)],
      ["local_staff_only", yesNo(c.local_staff_only)],
      ["platform_url", c.platform_url_configured ? i18n("admin.affiliate_resolver.health.configured") : i18n("admin.affiliate_resolver.health.missing")],
      ["api_token", c.api_token_configured ? i18n("admin.affiliate_resolver.health.configured") : i18n("admin.affiliate_resolver.health.missing")],
      ["timeout", `${c.request_timeout_ms || 0} ms`],
      ["click_beacon", yesNo(c.click_beacon_enabled)],
    ].map(([key, value]) => ({ label: i18n(`admin.affiliate_resolver.health.labels.${key}`), value }));
  }
  get cacheRows() {
    const c = this.data?.cache || {};
    return [
      ["cache_available", yesNo(c.available)],
      ["cache_version", c.version || i18n("admin.affiliate_resolver.health.not_available")],
      ["active_rules", String(c.active_rules || 0)],
      ["cache_fetched_at", formatDate(c.fetched_at)],
      ["cache_expires_at", formatDate(c.expires_at)],
    ].map(([key, value]) => ({ label: i18n(`admin.affiliate_resolver.health.labels.${key}`), value }));
  }
  get activityRows() {
    const a = this.data?.activity || {};
    return [
      ["last_rules_success", formatDate(a.last_rules_success_at)],
      ["last_rules_error", a.last_rules_error_code ? `${formatDate(a.last_rules_error_at)} — ${a.last_rules_error_code}` : i18n("admin.affiliate_resolver.health.not_available")],
      ["last_resolve_success", formatDate(a.last_resolve_success_at)],
      ["last_resolve_error", a.last_resolve_error_code ? `${formatDate(a.last_resolve_error_at)} — ${a.last_resolve_error_code}` : i18n("admin.affiliate_resolver.health.not_available")],
      ["last_latency", `${a.last_resolve_latency_ms || a.last_rules_latency_ms || 0} ms`],
    ].map(([key, value]) => ({ label: i18n(`admin.affiliate_resolver.health.labels.${key}`), value }));
  }
}
