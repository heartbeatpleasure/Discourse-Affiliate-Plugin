import { on } from "@ember/modifier";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <style>
    .affiliate-logs{display:flex;flex-direction:column;gap:1rem}.affiliate-logs__panel{background:var(--secondary);border:1px solid var(--primary-low);border-radius:16px;padding:1.15rem}.affiliate-logs__intro{margin:0;color:var(--primary-medium)}.affiliate-logs__actions{display:flex;gap:.5rem;flex-wrap:wrap}.affiliate-logs__table{width:100%;border-collapse:collapse}.affiliate-logs__table th,.affiliate-logs__table td{text-align:left;padding:.65rem;border-top:1px solid var(--primary-low);vertical-align:top}.affiliate-logs__error{border:1px solid var(--danger-low-mid);background:var(--danger-low);color:var(--danger);padding:.8rem;border-radius:10px}.affiliate-logs__scroll{overflow-x:auto}
  </style>

  <div class="admin-detail affiliate-logs">
    <DPageSubheader @titleLabel={{i18n "affiliate_resolver.logs.title"}} />

    <p class="affiliate-logs__intro">
      {{i18n "affiliate_resolver.logs.description"}}
    </p>

    <div class="affiliate-logs__actions">
      <button
        class="btn"
        type="button"
        disabled={{@controller.isLoading}}
        {{on "click" @controller.loadLogs}}
      >
        {{if
          @controller.isLoading
          (i18n "affiliate_resolver.logs.refreshing")
          (i18n "affiliate_resolver.logs.refresh")
        }}
      </button>
      <span class="affiliate-logs__intro">
        {{i18n
          "affiliate_resolver.logs.generated_at"
          time=@controller.generatedAt
        }}
      </span>
    </div>

    {{#if @controller.error}}
      <div class="affiliate-logs__error">{{@controller.error}}</div>
    {{/if}}

    <section class="affiliate-logs__panel affiliate-logs__scroll">
      {{#if @controller.events.length}}
        <table class="affiliate-logs__table">
          <thead>
            <tr>
              <th>{{i18n "affiliate_resolver.logs.occurred_at"}}</th>
              <th>{{i18n "affiliate_resolver.logs.severity"}}</th>
              <th>{{i18n "affiliate_resolver.logs.event"}}</th>
              <th>{{i18n "affiliate_resolver.logs.result"}}</th>
              <th>{{i18n "affiliate_resolver.logs.details"}}</th>
            </tr>
          </thead>
          <tbody>
            {{#each @controller.events as |event|}}
              <tr>
                <td>{{event.occurredAt}}</td>
                <td>{{event.severity}}</td>
                <td>{{event.event}}</td>
                <td>{{event.result}}</td>
                <td>{{event.detailsText}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else if @controller.isLoading}}
        {{i18n "affiliate_resolver.logs.loading"}}
      {{else}}
        {{i18n "affiliate_resolver.logs.empty"}}
      {{/if}}
    </section>
  </div>
</template>
