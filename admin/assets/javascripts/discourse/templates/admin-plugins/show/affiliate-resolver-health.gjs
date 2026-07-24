import { on } from "@ember/modifier";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <style>
    .affiliate-health{display:flex;flex-direction:column;gap:1rem}.affiliate-health__panel{background:var(--secondary);border:1px solid var(--primary-low);border-radius:16px;padding:1.15rem}.affiliate-health__intro{margin:0;color:var(--primary-medium)}.affiliate-health__actions{display:flex;gap:.5rem;flex-wrap:wrap}.affiliate-health__grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1rem}.affiliate-health__rows{display:flex;flex-direction:column;gap:.45rem;margin-top:.8rem}.affiliate-health__row{display:flex;justify-content:space-between;gap:1rem;border-top:1px solid var(--primary-low);padding-top:.45rem}.affiliate-health__error{border:1px solid var(--danger-low-mid);background:var(--danger-low);color:var(--danger);padding:.8rem;border-radius:10px}@media(max-width:700px){.affiliate-health__row{flex-direction:column}}
  </style>

  <div class="admin-detail affiliate-health">
    <DPageSubheader @titleLabel={{i18n "affiliate_resolver.health.title"}} />

    <p class="affiliate-health__intro">
      {{i18n "affiliate_resolver.health.description"}}
    </p>

    <div class="affiliate-health__actions">
      <button
        class="btn"
        type="button"
        disabled={{@controller.isLoading}}
        {{on "click" @controller.loadHealth}}
      >
        {{if
          @controller.isLoading
          (i18n "affiliate_resolver.health.refreshing")
          (i18n "affiliate_resolver.health.refresh")
        }}
      </button>
      <button
        class="btn btn-primary"
        type="button"
        disabled={{@controller.isRefreshingRules}}
        {{on "click" @controller.refreshRules}}
      >
        {{if
          @controller.isRefreshingRules
          (i18n "affiliate_resolver.health.testing")
          (i18n "affiliate_resolver.health.test_rules")
        }}
      </button>
    </div>

    {{#if @controller.error}}
      <div class="affiliate-health__error">{{@controller.error}}</div>
    {{/if}}

    {{#if @controller.data}}
      <section class="affiliate-health__panel">
        <h3>{{i18n "affiliate_resolver.health.overall"}}</h3>
        <p>{{@controller.overallLabel}}</p>
        <p class="affiliate-health__intro">
          {{i18n
            "affiliate_resolver.health.generated_at"
            time=@controller.generatedAt
          }}
        </p>
      </section>

      <div class="affiliate-health__grid">
        <section class="affiliate-health__panel">
          <h3>{{i18n "affiliate_resolver.health.configuration"}}</h3>
          <div class="affiliate-health__rows">
            {{#each @controller.configurationRows as |row|}}
              <div class="affiliate-health__row">
                <strong>{{row.label}}</strong>
                <span>{{row.value}}</span>
              </div>
            {{/each}}
          </div>
        </section>

        <section class="affiliate-health__panel">
          <h3>{{i18n "affiliate_resolver.health.cache"}}</h3>
          <div class="affiliate-health__rows">
            {{#each @controller.cacheRows as |row|}}
              <div class="affiliate-health__row">
                <strong>{{row.label}}</strong>
                <span>{{row.value}}</span>
              </div>
            {{/each}}
          </div>
        </section>

        <section class="affiliate-health__panel">
          <h3>{{i18n "affiliate_resolver.health.recent_activity"}}</h3>
          <div class="affiliate-health__rows">
            {{#each @controller.activityRows as |row|}}
              <div class="affiliate-health__row">
                <strong>{{row.label}}</strong>
                <span>{{row.value}}</span>
              </div>
            {{/each}}
          </div>
        </section>
      </div>
    {{else if @controller.isLoading}}
      <section class="affiliate-health__panel">
        {{i18n "affiliate_resolver.health.loading"}}
      </section>
    {{/if}}
  </div>
</template>
