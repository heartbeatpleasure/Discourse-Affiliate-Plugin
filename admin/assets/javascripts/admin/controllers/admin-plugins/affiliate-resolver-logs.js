import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

function extractError(error) {
  return error?.jqXHR?.responseJSON?.errors?.[0] || error?.message || i18n("admin.affiliate_resolver.logs.load_error");
}

function formatDate(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? value : new Intl.DateTimeFormat(undefined, { dateStyle: "medium", timeStyle: "medium" }).format(date);
}

export default class AdminPluginsAffiliateResolverLogsController extends Controller {
  @tracked data = null;
  @tracked isLoading = false;
  @tracked error = null;

  resetState() {
    this.data = null;
    this.error = null;
  }

  @action
  async loadLogs() {
    if (this.isLoading) return;
    this.isLoading = true;
    this.error = null;
    try {
      this.data = await ajax("/admin/plugins/affiliate-resolver/logs.json");
    } catch (error) {
      this.error = extractError(error);
    } finally {
      this.isLoading = false;
    }
  }

  get events() {
    return (this.data?.events || []).map((event) => ({
      ...event,
      occurredAt: formatDate(event.occurred_at),
      detailsText: Object.entries(event.details || {}).map(([key, value]) => `${key}: ${value}`).join(", ") || "—",
    }));
  }

  get generatedAt() { return this.data?.generated_at ? formatDate(this.data.generated_at) : "—"; }
}
