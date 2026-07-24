import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

const KNOWN_URL_ERRORS = new Set([
  "missing",
  "invalid",
  "https_required",
  "host_missing",
  "credentials_not_allowed",
  "query_not_allowed",
  "fragment_not_allowed",
  "path_not_allowed",
  "host_not_allowed",
  "ip_literal_not_allowed",
]);

const KNOWN_PLATFORM_ERRORS = new Set([
  "unauthorized",
  "forbidden",
  "rate_limited",
  "timeout",
  "unavailable",
  "invalid_json",
  "invalid_response",
  "response_too_large",
  "http_error",
  "token_missing",
  "cache_missing",
]);

function formatDate(value) {
  if (!value) {
    return i18n("admin.affiliate_resolver.health.not_available");
  }

  const date = new Date(value);

  return Number.isNaN(date.getTime())
    ? i18n("admin.affiliate_resolver.health.not_available")
    : new Intl.DateTimeFormat(undefined, {
        dateStyle: "medium",
        timeStyle: "medium",
      }).format(date);
}

function yesNo(value) {
  return value
    ? i18n("admin.affiliate_resolver.health.yes")
    : i18n("admin.affiliate_resolver.health.no");
}

function extractError(error) {
  return (
    error?.jqXHR?.responseJSON?.errors?.[0] ||
    error?.message ||
    i18n("admin.affiliate_resolver.health.load_error")
  );
}

function urlErrorLabel(code) {
  const normalized = KNOWN_URL_ERRORS.has(code) ? code : "invalid";
  return i18n(`admin.affiliate_resolver.health.url_errors.${normalized}`);
}

function platformErrorLabel(code) {
  if (!code) {
    return i18n("admin.affiliate_resolver.health.not_available");
  }

  if (KNOWN_URL_ERRORS.has(code)) {
    return urlErrorLabel(code);
  }

  const normalized = KNOWN_PLATFORM_ERRORS.has(code) ? code : "unknown";
  return i18n(`admin.affiliate_resolver.health.platform_errors.${normalized}`);
}

export default class AdminPluginsAffiliateResolverHealthController extends Controller {
  @tracked data = null;
  @tracked isLoading = false;
  @tracked isTestingPlatform = false;
  @tracked error = null;

  resetState() {
    this.data = null;
    this.error = null;
  }

  @action
  async loadHealth() {
    if (this.isLoading) {
      return;
    }

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
  async testPlatform() {
    if (this.isTestingPlatform) {
      return;
    }

    this.isTestingPlatform = true;
    this.error = null;

    try {
      this.data = await ajax(
        "/admin/plugins/affiliate-resolver/health/refresh.json",
        { type: "POST" }
      );
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.isTestingPlatform = false;
    }
  }

  get generatedAtLabel() {
    return formatDate(this.data?.generated_at);
  }

  get overallState() {
    return this.data?.overall?.state || "inactive";
  }

  get overallSeverity() {
    return this.data?.overall?.severity || "info";
  }

  get overallLabel() {
    return i18n(
      `admin.affiliate_resolver.health.state.${this.overallState}`
    );
  }

  get overallBadgeClass() {
    return `is-${this.overallSeverity}`;
  }

  get summaryCards() {
    const configuration = this.data?.configuration || {};
    const cache = this.data?.cache || {};
    const activity = this.data?.activity || {};

    return [
      {
        label: i18n(
          "admin.affiliate_resolver.health.summary.platform_connection"
        ),
        value: this.platformConnectionValue,
        detail: this.platformConnectionDetail,
        badgeClass: this.platformConnectionBadgeClass,
      },
      {
        label: i18n("admin.affiliate_resolver.health.summary.rules_cache"),
        value: cache.available
          ? i18n("admin.affiliate_resolver.health.summary.active_rules", {
              count: cache.active_rules || 0,
            })
          : i18n("admin.affiliate_resolver.health.summary.not_available"),
        detail: cache.available
          ? i18n("admin.affiliate_resolver.health.summary.cache_detail", {
              time: formatDate(cache.fetched_at),
            })
          : i18n("admin.affiliate_resolver.health.summary.cache_empty_detail"),
        badgeClass: cache.available ? "is-ok" : "is-warning",
      },
      {
        label: i18n("admin.affiliate_resolver.health.summary.pilot_mode"),
        value: configuration.plugin_enabled
          ? this.pilotModeValue
          : i18n("admin.affiliate_resolver.health.summary.plugin_disabled"),
        detail: i18n("admin.affiliate_resolver.health.summary.pilot_detail", {
          timeout: configuration.request_timeout_ms || 0,
          beacon: yesNo(configuration.click_beacon_enabled),
        }),
        badgeClass: configuration.plugin_enabled ? "is-info" : "is-warning",
      },
      {
        label: i18n("admin.affiliate_resolver.health.summary.last_platform_call"),
        value: activity.last_rules_success_at
          ? formatDate(activity.last_rules_success_at)
          : i18n("admin.affiliate_resolver.health.summary.not_tested"),
        detail: activity.last_rules_latency_ms
          ? i18n("admin.affiliate_resolver.health.summary.latency_detail", {
              latency: activity.last_rules_latency_ms,
            })
          : i18n("admin.affiliate_resolver.health.summary.no_latency"),
        badgeClass: activity.last_rules_success_at ? "is-ok" : "is-info",
      },
    ];
  }

  get platformConnectionValue() {
    const configuration = this.data?.configuration || {};
    const activity = this.data?.activity || {};
    const cache = this.data?.cache || {};

    if (!configuration.platform_url_configured) {
      return urlErrorLabel(configuration.platform_url_error_code);
    }

    if (!configuration.api_token_configured) {
      return i18n("admin.affiliate_resolver.health.summary.token_missing");
    }

    if (activity.last_rules_error_code && !activity.last_rules_success_at) {
      return i18n("admin.affiliate_resolver.health.summary.connection_failed");
    }

    if (cache.available && activity.last_rules_success_at) {
      return i18n("admin.affiliate_resolver.health.summary.connected");
    }

    return i18n("admin.affiliate_resolver.health.summary.not_tested");
  }

  get platformConnectionDetail() {
    const configuration = this.data?.configuration || {};
    const activity = this.data?.activity || {};

    if (!configuration.platform_url_configured) {
      return i18n("admin.affiliate_resolver.health.summary.url_invalid_detail");
    }

    if (!configuration.api_token_configured) {
      return i18n("admin.affiliate_resolver.health.summary.token_missing_detail");
    }

    if (activity.last_rules_error_code) {
      return platformErrorLabel(activity.last_rules_error_code);
    }

    return i18n("admin.affiliate_resolver.health.summary.connection_ready_detail");
  }

  get platformConnectionBadgeClass() {
    const configuration = this.data?.configuration || {};
    const activity = this.data?.activity || {};
    const cache = this.data?.cache || {};

    if (
      !configuration.platform_url_configured ||
      !configuration.api_token_configured ||
      activity.last_rules_error_code
    ) {
      return "is-critical";
    }

    return cache.available ? "is-ok" : "is-info";
  }

  get pilotModeValue() {
    const configuration = this.data?.configuration || {};
    const parts = [];

    parts.push(
      configuration.local_observe_only
        ? i18n("admin.affiliate_resolver.health.summary.observe_only")
        : i18n("admin.affiliate_resolver.health.summary.rewrite_active")
    );

    parts.push(
      configuration.local_staff_only
        ? i18n("admin.affiliate_resolver.health.summary.staff_only")
        : i18n("admin.affiliate_resolver.health.summary.all_members")
    );

    return parts.join(" · ");
  }

  get warnings() {
    const configuration = this.data?.configuration || {};
    const cache = this.data?.cache || {};
    const activity = this.data?.activity || {};
    const warnings = [];

    if (!configuration.plugin_enabled) {
      warnings.push(this.warning("plugin_disabled", "info"));
    }

    if (!configuration.platform_url_configured) {
      const code = KNOWN_URL_ERRORS.has(configuration.platform_url_error_code)
        ? configuration.platform_url_error_code
        : "invalid";
      warnings.push(this.warning(`url_${code}`, "critical"));
    }

    if (!configuration.api_token_configured) {
      warnings.push(this.warning("token_missing", "critical"));
    }

    if (
      configuration.plugin_enabled &&
      configuration.platform_url_configured &&
      configuration.api_token_configured &&
      !cache.available
    ) {
      warnings.push(this.warning("cache_unavailable", "warning"));
    }

    if (cache.available && !cache.enabled) {
      warnings.push(this.warning("platform_disabled", "warning"));
    }

    if (cache.available && cache.active_rules === 0) {
      warnings.push(this.warning("no_active_rules", "info"));
    }

    if (!configuration.local_observe_only) {
      warnings.push(this.warning("local_rewrite_active", "warning"));
    }

    if (!configuration.local_staff_only) {
      warnings.push(this.warning("all_members_enabled", "warning"));
    }

    if (activity.last_rules_error_code) {
      warnings.push({
        title: i18n(
          "admin.affiliate_resolver.health.warnings.last_rules_error.title"
        ),
        description: i18n(
          "admin.affiliate_resolver.health.warnings.last_rules_error.description",
          {
            error: platformErrorLabel(activity.last_rules_error_code),
            time: formatDate(activity.last_rules_error_at),
          }
        ),
        badgeClass: "is-warning",
      });
    }

    return warnings;
  }

  get hasWarnings() {
    return this.warnings.length > 0;
  }

  get configurationRows() {
    const configuration = this.data?.configuration || {};

    return [
      ["plugin_enabled", yesNo(configuration.plugin_enabled)],
      ["local_observe_only", yesNo(configuration.local_observe_only)],
      ["local_staff_only", yesNo(configuration.local_staff_only)],
      [
        "platform_url",
        configuration.platform_url_configured
          ? i18n("admin.affiliate_resolver.health.configured_https")
          : urlErrorLabel(configuration.platform_url_error_code),
      ],
      [
        "api_token",
        configuration.api_token_configured
          ? i18n("admin.affiliate_resolver.health.configured")
          : i18n("admin.affiliate_resolver.health.missing"),
      ],
      ["timeout", `${configuration.request_timeout_ms || 0} ms`],
      ["click_beacon", yesNo(configuration.click_beacon_enabled)],
    ].map(([key, value]) => ({
      label: i18n(`admin.affiliate_resolver.health.labels.${key}`),
      value,
    }));
  }

  get cacheRows() {
    const cache = this.data?.cache || {};

    return [
      ["cache_available", yesNo(cache.available)],
      ["platform_enabled", yesNo(cache.enabled)],
      ["platform_observe_only", yesNo(cache.platform_observe_only)],
      [
        "cache_version",
        cache.version || i18n("admin.affiliate_resolver.health.not_available"),
      ],
      ["active_rules", String(cache.active_rules || 0)],
      ["cache_fetched_at", formatDate(cache.fetched_at)],
      ["cache_expires_at", formatDate(cache.expires_at)],
    ].map(([key, value]) => ({
      label: i18n(`admin.affiliate_resolver.health.labels.${key}`),
      value,
    }));
  }

  get activityRows() {
    const activity = this.data?.activity || {};

    return [
      ["last_rules_success", formatDate(activity.last_rules_success_at)],
      [
        "last_rules_error",
        activity.last_rules_error_code
          ? `${formatDate(activity.last_rules_error_at)} — ${platformErrorLabel(
              activity.last_rules_error_code
            )}`
          : i18n("admin.affiliate_resolver.health.not_available"),
      ],
      ["last_rules_latency", `${activity.last_rules_latency_ms || 0} ms`],
      ["last_resolve_success", formatDate(activity.last_resolve_success_at)],
      [
        "last_resolve_error",
        activity.last_resolve_error_code
          ? `${formatDate(activity.last_resolve_error_at)} — ${platformErrorLabel(
              activity.last_resolve_error_code
            )}`
          : i18n("admin.affiliate_resolver.health.not_available"),
      ],
      ["last_resolve_latency", `${activity.last_resolve_latency_ms || 0} ms`],
    ].map(([key, value]) => ({
      label: i18n(`admin.affiliate_resolver.health.labels.${key}`),
      value,
    }));
  }

  warning(key, severity) {
    return {
      title: i18n(`admin.affiliate_resolver.health.warnings.${key}.title`),
      description: i18n(
        `admin.affiliate_resolver.health.warnings.${key}.description`
      ),
      badgeClass: `is-${severity}`,
    };
  }
}
