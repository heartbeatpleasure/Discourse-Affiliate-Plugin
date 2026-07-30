import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

/**
 * Make the Settings control on /admin/plugins for this plugin open the
 * Affiliate Resolver settings through the reliable setting-key prefix.
 *
 * Some Discourse builds generate a `plugin:<metadata name>` filter for the
 * Installed Plugins button. That token can render an empty result while the
 * plain `affiliate_resolver` setting-key filter works correctly.
 *
 * This initializer only targets the Discourse Affiliate Plugin card. It does
 * not rename the plugin, alter settings ownership, or affect other controls.
 */
export default apiInitializer("0.11.1", (api) => {
  const PLUGIN_DISPLAY_NAME = "Discourse-Affiliate-Plugin";
  const FIXED_SETTINGS_URL =
    "/admin/site_settings/category/all_results?filter=affiliate_resolver";

  let observer = null;
  let clickHandlerInstalled = false;

  function findPluginCards() {
    return Array.from(document.querySelectorAll("[data-plugin-name]")).concat(
      Array.from(
        document.querySelectorAll(
          ".admin-plugins-list .admin-plugin, .admin-plugin",
        ),
      ),
    );
  }

  function cardLooksLikeOurPlugin(card) {
    if (!card) {
      return false;
    }

    const dataName = card.getAttribute?.("data-plugin-name");
    if (
      dataName &&
      dataName.toLowerCase() === PLUGIN_DISPLAY_NAME.toLowerCase()
    ) {
      return true;
    }

    const text = (card.textContent || "").toLowerCase();
    if (text.includes(PLUGIN_DISPLAY_NAME.toLowerCase())) {
      return true;
    }

    return Boolean(
      card.querySelector?.('a[href*="Discourse-Affiliate-Plugin"]'),
    );
  }

  function rewriteSettingsLinkInCard(card) {
    if (!cardLooksLikeOurPlugin(card)) {
      return;
    }

    const anchors = Array.from(
      card.querySelectorAll('a[href*="/admin/site_settings"]'),
    );

    for (const anchor of anchors) {
      if (anchor.dataset.affiliateResolverSettingsFixed === "1") {
        continue;
      }

      anchor.setAttribute("href", FIXED_SETTINGS_URL);
      anchor.dataset.affiliateResolverSettingsFixed = "1";
    }
  }

  function rewriteAll() {
    schedule("afterRender", () => {
      findPluginCards().forEach((card) => rewriteSettingsLinkInCard(card));
    });
  }

  function installClickInterceptOnce() {
    if (clickHandlerInstalled) {
      return;
    }

    clickHandlerInstalled = true;

    // Capture phase also covers Discourse versions where Settings is rendered
    // as a JavaScript action/button rather than a normal anchor.
    document.addEventListener(
      "click",
      (event) => {
        if (!window.location?.pathname?.startsWith("/admin/plugins")) {
          return;
        }

        const target = event.target;
        if (!target) {
          return;
        }

        const control =
          target.closest?.(
            'a[href*="/admin/site_settings"], button, .btn, .d-button',
          ) || target;

        const label = `${control.getAttribute?.("aria-label") || ""} ${
          control.getAttribute?.("title") || ""
        }`;
        const href = control.getAttribute?.("href") || "";
        const settingsControl =
          label.toLowerCase().includes("settings") ||
          href.includes("/admin/site_settings");

        if (!settingsControl) {
          return;
        }

        const card = control.closest?.("[data-plugin-name], .admin-plugin");
        if (!cardLooksLikeOurPlugin(card)) {
          return;
        }

        event.preventDefault();
        event.stopPropagation();
        window.location.assign(FIXED_SETTINGS_URL);
      },
      true,
    );
  }

  function start() {
    rewriteAll();
    installClickInterceptOnce();

    observer?.disconnect();
    observer = new MutationObserver(() => rewriteAll());
    observer.observe(document.body, { childList: true, subtree: true });
  }

  function stop() {
    observer?.disconnect();
    observer = null;
  }

  api.onPageChange((url) => {
    if (url?.startsWith("/admin/plugins")) {
      start();
    } else {
      stop();
    }
  });

  if (window.location?.pathname?.startsWith("/admin/plugins")) {
    start();
  }
});
