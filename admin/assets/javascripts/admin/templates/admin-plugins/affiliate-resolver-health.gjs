import RouteTemplate from "ember-route-template";
import { on } from "@ember/modifier";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <style>
      .affiliate-health {
        --affiliate-health-surface: var(--secondary);
        --affiliate-health-surface-alt: var(--primary-very-low);
        --affiliate-health-border: var(--primary-low);
        --affiliate-health-muted: var(--primary-medium);
        --affiliate-health-radius: 18px;
        display: flex;
        flex-direction: column;
        gap: 1rem;
      }

      .affiliate-health h1,
      .affiliate-health h2,
      .affiliate-health h3,
      .affiliate-health p {
        margin: 0;
      }

      .affiliate-health__hero,
      .affiliate-health__panel {
        min-width: 0;
        border: 1px solid var(--affiliate-health-border);
        border-radius: var(--affiliate-health-radius);
        background: var(--affiliate-health-surface);
        box-shadow: 0 1px 2px rgba(0, 0, 0, 0.03);
      }

      .affiliate-health__hero {
        padding: 1.15rem 1.25rem;
      }

      .affiliate-health__panel {
        padding: 1rem 1.125rem;
      }

      .affiliate-health__header,
      .affiliate-health__panel-header {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1rem;
      }

      .affiliate-health__header-copy,
      .affiliate-health__panel-copy {
        display: flex;
        min-width: 0;
        flex-direction: column;
        gap: 0.3rem;
      }

      .affiliate-health__muted,
      .affiliate-health__card-detail {
        color: var(--affiliate-health-muted);
        font-size: var(--font-down-1);
      }

      .affiliate-health__action-area {
        display: flex;
        max-width: 680px;
        flex-direction: column;
        align-items: flex-end;
      }

      .affiliate-health__actions {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        justify-content: flex-end;
        gap: 0.65rem;
      }


      .affiliate-health__status {
        display: inline-flex;
        min-height: 2.2rem;
        align-items: center;
        gap: 0.45rem;
        border: 1px solid var(--affiliate-health-border);
        border-radius: 999px;
        background: var(--affiliate-health-surface-alt);
        padding: 0.35rem 0.7rem;
        font-weight: 700;
      }

      .affiliate-health__status-dot {
        width: 0.72rem;
        height: 0.72rem;
        flex: 0 0 auto;
        border-radius: 999px;
        background: var(--primary-medium);
      }

      .affiliate-health__status-dot.is-ok {
        background: var(--success);
      }

      .affiliate-health__status-dot.is-warning {
        background: var(--highlight);
      }

      .affiliate-health__status-dot.is-critical {
        background: var(--danger);
      }

      .affiliate-health__status-dot.is-info {
        background: var(--primary-medium);
      }

      .affiliate-health__summary-grid,
      .affiliate-health__detail-grid {
        display: grid;
        gap: 1rem;
      }

      .affiliate-health__summary-grid {
        grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
      }

      .affiliate-health__detail-grid {
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      }

      .affiliate-health__summary-card,
      .affiliate-health__detail-card,
      .affiliate-health__warning {
        min-width: 0;
        border: 1px solid var(--affiliate-health-border);
        border-radius: 16px;
        background: var(--affiliate-health-surface-alt);
      }

      .affiliate-health__summary-card {
        position: relative;
        display: flex;
        flex-direction: column;
        gap: 0.35rem;
        padding: 0.9rem 1rem;
      }

      .affiliate-health__summary-card .affiliate-health__badge {
        position: absolute;
        top: 0.8rem;
        right: 0.8rem;
      }

      .affiliate-health__card-label,
      .affiliate-health__row-label {
        color: var(--affiliate-health-muted);
        font-size: var(--font-down-1);
        font-weight: 700;
      }

      .affiliate-health__card-value {
        padding-right: 1.8rem;
        overflow-wrap: anywhere;
        font-size: var(--font-up-1);
        font-weight: 700;
        line-height: 1.2;
        white-space: pre-line;
      }

      .affiliate-health__badge {
        display: inline-flex;
        min-width: 1.25rem;
        min-height: 1.25rem;
        align-items: center;
        justify-content: center;
        border: 1px solid var(--affiliate-health-border);
        border-radius: 999px;
        padding: 0.15rem 0.4rem;
        font-size: var(--font-down-2);
        font-weight: 800;
        line-height: 1;
      }

      .affiliate-health__badge.is-ok {
        border-color: var(--success-low-mid);
        background: var(--success-low);
        color: var(--success);
      }

      .affiliate-health__badge.is-warning {
        border-color: var(--highlight-medium);
        background: var(--highlight-low);
        color: var(--primary-high);
      }

      .affiliate-health__badge.is-critical {
        border-color: var(--danger-low-mid);
        background: var(--danger-low);
        color: var(--danger);
      }

      .affiliate-health__badge.is-info {
        border-color: var(--primary-low);
        background: var(--primary-very-low);
        color: var(--primary-high);
      }

      .affiliate-health__warnings {
        display: grid;
        gap: 0.75rem;
        margin-top: 1rem;
      }

      .affiliate-health__warning {
        display: grid;
        grid-template-columns: auto minmax(0, 1fr);
        align-items: flex-start;
        gap: 0.75rem;
        padding: 0.8rem 0.9rem;
      }

      .affiliate-health__warning-copy {
        display: flex;
        min-width: 0;
        flex-direction: column;
        gap: 0.2rem;
      }

      .affiliate-health__warning-title {
        font-weight: 700;
      }

      .affiliate-health__notice,
      .affiliate-health__error {
        border-radius: 14px;
        padding: 0.8rem 0.9rem;
      }

      .affiliate-health__notice {
        margin-top: 1rem;
        border: 1px solid var(--success-low-mid);
        background: var(--success-low);
        color: var(--success);
      }

      .affiliate-health__error {
        border: 1px solid var(--danger-low-mid);
        background: var(--danger-low);
        color: var(--danger);
      }

      .affiliate-health__detail-card {
        padding: 0.9rem 1rem;
      }

      .affiliate-health__rows {
        display: flex;
        flex-direction: column;
        gap: 0.55rem;
        margin-top: 0.8rem;
      }

      .affiliate-health__row {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 1rem;
        border-top: 1px solid var(--affiliate-health-border);
        padding-top: 0.55rem;
      }

      .affiliate-health__row-value {
        max-width: 60%;
        overflow-wrap: anywhere;
        text-align: right;
        font-weight: 600;
      }

      @media (max-width: 880px) {
        .affiliate-health__header,
        .affiliate-health__panel-header {
          flex-direction: column;
        }

        .affiliate-health__action-area {
          max-width: none;
          align-items: flex-start;
        }

        .affiliate-health__actions {
          justify-content: flex-start;
        }
      }

      @media (max-width: 620px) {
        .affiliate-health__summary-grid,
        .affiliate-health__detail-grid {
          grid-template-columns: 1fr;
        }

        .affiliate-health__row {
          flex-direction: column;
          gap: 0.2rem;
        }

        .affiliate-health__row-value {
          max-width: none;
          text-align: left;
        }
      }
    </style>

    <div class="affiliate-health">
      <section class="affiliate-health__hero">
        <div class="affiliate-health__header">
          <div class="affiliate-health__header-copy">
            <h1>{{i18n "admin.affiliate_resolver.health.title"}}</h1>
            <p class="affiliate-health__muted">
              {{i18n "admin.affiliate_resolver.health.description"}}
            </p>
            <p class="affiliate-health__muted">
              {{i18n
                "admin.affiliate_resolver.health.last_checked"
                time=@controller.generatedAtLabel
              }}
            </p>
          </div>

          <div class="affiliate-health__action-area">
            <div class="affiliate-health__actions">
              <span class="affiliate-health__status">
                <span
                  class="affiliate-health__status-dot {{@controller.overallBadgeClass}}"
                ></span>
                <span>{{@controller.overallLabel}}</span>
              </span>

              <button
                class="btn"
                type="button"
                disabled={{@controller.isLoading}}
                title={{i18n "admin.affiliate_resolver.health.refresh_help"}}
                {{on "click" @controller.loadHealth}}
              >
                {{if
                  @controller.isLoading
                  (i18n "admin.affiliate_resolver.health.refreshing")
                  (i18n "admin.affiliate_resolver.health.refresh")
                }}
              </button>

              <button
                class="btn btn-primary"
                type="button"
                disabled={{@controller.isCheckingPlatform}}
                title={{i18n "admin.affiliate_resolver.health.check_platform_help"}}
                {{on "click" @controller.checkPlatform}}
              >
                {{if
                  @controller.isCheckingPlatform
                  (i18n "admin.affiliate_resolver.health.checking")
                  (i18n "admin.affiliate_resolver.health.check_platform")
                }}
              </button>

              <a class="btn" href="/admin/plugins/affiliate-resolver-logs">
                {{i18n "admin.affiliate_resolver.logs.short_title"}}
              </a>

              <a
                class="btn"
                href="/admin/site_settings/category/all_results?filter=affiliate_resolver"
              >
                {{i18n "admin.affiliate_resolver.open_settings"}}
              </a>

              <a class="btn" href="/admin/plugins/affiliate-resolver">
                {{i18n "admin.affiliate_resolver.health.back_to_overview"}}
              </a>
            </div>
          </div>
        </div>
      </section>

      {{#if @controller.error}}
        <div class="affiliate-health__error">{{@controller.error}}</div>
      {{/if}}

      {{#if @controller.data}}
        <section class="affiliate-health__summary-grid">
          {{#each @controller.summaryCards as |card|}}
            <article class="affiliate-health__summary-card">
              <span class="affiliate-health__badge {{card.badgeClass}}">●</span>
              <p class="affiliate-health__card-label">{{card.label}}</p>
              <p class="affiliate-health__card-value">{{card.value}}</p>
              <p class="affiliate-health__card-detail">{{card.detail}}</p>
            </article>
          {{/each}}
        </section>

        <section class="affiliate-health__panel">
          <div class="affiliate-health__panel-header">
            <div class="affiliate-health__panel-copy">
              <h2>{{i18n "admin.affiliate_resolver.health.operational_status"}}</h2>
              <p class="affiliate-health__muted">
                {{i18n "admin.affiliate_resolver.health.operational_description"}}
              </p>
            </div>
          </div>

          {{#if @controller.hasWarnings}}
            <div class="affiliate-health__warnings">
              {{#each @controller.warnings as |warning|}}
                <article class="affiliate-health__warning">
                  <span class="affiliate-health__badge {{warning.badgeClass}}">!</span>
                  <div class="affiliate-health__warning-copy">
                    <p class="affiliate-health__warning-title">{{warning.title}}</p>
                    <p class="affiliate-health__muted">{{warning.description}}</p>
                  </div>
                </article>
              {{/each}}
            </div>
          {{else}}
            <div class="affiliate-health__notice">
              {{i18n "admin.affiliate_resolver.health.no_warnings"}}
            </div>
          {{/if}}
        </section>

        <section class="affiliate-health__detail-grid">
          <article class="affiliate-health__detail-card">
            <h2>{{i18n "admin.affiliate_resolver.health.configuration"}}</h2>
            <div class="affiliate-health__rows">
              {{#each @controller.configurationRows as |row|}}
                <div class="affiliate-health__row">
                  <span class="affiliate-health__row-label">{{row.label}}</span>
                  <span class="affiliate-health__row-value">{{row.value}}</span>
                </div>
              {{/each}}
            </div>
          </article>

          <article class="affiliate-health__detail-card">
            <h2>{{i18n "admin.affiliate_resolver.health.cache"}}</h2>
            <div class="affiliate-health__rows">
              {{#each @controller.cacheRows as |row|}}
                <div class="affiliate-health__row">
                  <span class="affiliate-health__row-label">{{row.label}}</span>
                  <span class="affiliate-health__row-value">{{row.value}}</span>
                </div>
              {{/each}}
            </div>
          </article>

          <article class="affiliate-health__detail-card">
            <h2>{{i18n "admin.affiliate_resolver.health.recent_activity"}}</h2>
            <div class="affiliate-health__rows">
              {{#each @controller.activityRows as |row|}}
                <div class="affiliate-health__row">
                  <span class="affiliate-health__row-label">{{row.label}}</span>
                  <span class="affiliate-health__row-value">{{row.value}}</span>
                </div>
              {{/each}}
            </div>
          </article>
        </section>
      {{else if @controller.isLoading}}
        <section class="affiliate-health__panel">
          {{i18n "admin.affiliate_resolver.health.loading"}}
        </section>
      {{/if}}
    </div>
  </template>
);
