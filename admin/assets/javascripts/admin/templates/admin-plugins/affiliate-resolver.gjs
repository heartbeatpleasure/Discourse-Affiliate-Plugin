import RouteTemplate from "ember-route-template";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <style>
      .affiliate-admin { display:flex; flex-direction:column; gap:1rem; }
      .affiliate-admin__hero,.affiliate-admin__card { background:var(--secondary); border:1px solid var(--primary-low); border-radius:16px; padding:1.2rem; }
      .affiliate-admin__hero { display:flex; justify-content:space-between; align-items:flex-start; gap:1rem; }
      .affiliate-admin__hero h1,.affiliate-admin__hero p,.affiliate-admin__card h2,.affiliate-admin__card p { margin:0; }
      .affiliate-admin__copy { display:flex; flex-direction:column; gap:.4rem; max-width:760px; }
      .affiliate-admin__muted { color:var(--primary-medium); }
      .affiliate-admin__grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(250px,1fr)); gap:1rem; }
      .affiliate-admin__card { color:var(--primary); text-decoration:none; display:flex; flex-direction:column; gap:.65rem; min-height:150px; }
      .affiliate-admin__card:hover { border-color:var(--tertiary-medium); text-decoration:none; color:var(--primary); }
      .affiliate-admin__action { color:var(--tertiary); font-weight:600; margin-top:auto; }
      @media(max-width:700px){.affiliate-admin__hero{flex-direction:column}.affiliate-admin__grid{grid-template-columns:1fr}}
    </style>
    <div class="affiliate-admin">
      <section class="affiliate-admin__hero">
        <div class="affiliate-admin__copy">
          <h1>{{i18n "admin.affiliate_resolver.title"}}</h1>
          <p class="affiliate-admin__muted">{{i18n "admin.affiliate_resolver.description"}}</p>
        </div>
        <a class="btn btn-primary" href="/admin/site_settings/category/all_results?filter=affiliate_resolver">{{i18n "admin.affiliate_resolver.open_settings"}}</a>
      </section>
      <div class="affiliate-admin__copy">
        <h2>{{i18n "admin.affiliate_resolver.overview_title"}}</h2>
        <p class="affiliate-admin__muted">{{i18n "admin.affiliate_resolver.overview_description"}}</p>
      </div>
      <section class="affiliate-admin__grid">
        <a class="affiliate-admin__card" href="/admin/site_settings/category/all_results?filter=affiliate_resolver">
          <h2>{{i18n "admin.affiliate_resolver.settings_title"}}</h2>
          <p class="affiliate-admin__muted">{{i18n "admin.affiliate_resolver.settings_description"}}</p>
          <span class="affiliate-admin__action">{{i18n "admin.affiliate_resolver.open_tool"}}</span>
        </a>
        <a class="affiliate-admin__card" href="/admin/plugins/affiliate-resolver-health">
          <h2>{{i18n "admin.affiliate_resolver.health.short_title"}}</h2>
          <p class="affiliate-admin__muted">{{i18n "admin.affiliate_resolver.health.description"}}</p>
          <span class="affiliate-admin__action">{{i18n "admin.affiliate_resolver.open_tool"}}</span>
        </a>
        <a class="affiliate-admin__card" href="/admin/plugins/affiliate-resolver-logs">
          <h2>{{i18n "admin.affiliate_resolver.logs.short_title"}}</h2>
          <p class="affiliate-admin__muted">{{i18n "admin.affiliate_resolver.logs.description"}}</p>
          <span class="affiliate-admin__action">{{i18n "admin.affiliate_resolver.open_tool"}}</span>
        </a>
      </section>
    </div>
  </template>
);
