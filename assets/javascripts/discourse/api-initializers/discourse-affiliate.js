import { ajax } from "discourse/lib/ajax";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

const MAX_LINKS = 50;
const PROCESSED_ATTRIBUTE = "data-affiliate-resolver-processed";
const ORIGINAL_HREF_ATTRIBUTE = "data-affiliate-resolver-original-href";
const ORIGINAL_REL_ATTRIBUTE = "data-affiliate-resolver-original-rel";
const ORIGINAL_REFERRER_ATTRIBUTE = "data-affiliate-resolver-original-referrer-policy";
const GENERATED_SELECTOR = "[data-affiliate-resolver-generated]";
const beaconHandlers = new WeakMap();
const inFlightElements = new WeakSet();

export const COOKED_DECORATOR_OPTIONS = {
  id: "discourse-affiliate-resolver",
  onlyStream: true,
};

const EXCLUDED_SELECTOR = [
  "blockquote a",
  ".quote a",
  "a.mention",
  "a.mention-group",
  "a.hashtag-cooked",
  "a.lightbox",
  "a.attachment",
].join(",");

function externalHttpsUrlFromValue(value) {
  try {
    const url = new URL(value, window.location.origin);
    if (url.protocol !== "https:" || url.origin === window.location.origin) {
      return null;
    }
    return url.href;
  } catch {
    return null;
  }
}

function externalHttpsUrl(anchor) {
  const sourceHref =
    anchor.getAttribute(ORIGINAL_HREF_ATTRIBUTE) || anchor.href;
  return externalHttpsUrlFromValue(sourceHref);
}

export function affiliateCandidateUrl(anchor) {
  const href = externalHttpsUrl(anchor);
  if (!href) {
    return null;
  }

  const onebox = anchor.closest(
    "aside.onebox[data-onebox-src], .onebox[data-onebox-src]"
  );
  if (!onebox) {
    return href;
  }

  const sourceUrl = externalHttpsUrlFromValue(
    onebox.getAttribute("data-onebox-src")
  );

  // Oneboxes can contain author, metadata, or related links. Only links that
  // point to the original oneboxed URL may inherit its affiliate rewrite.
  return sourceUrl && href === sourceUrl ? sourceUrl : null;
}

function eligibleAnchors(element) {
  const entriesByUrl = new Map();

  for (const anchor of element.querySelectorAll("a[href]")) {
    if (anchor.matches(EXCLUDED_SELECTOR)) {
      continue;
    }
    if (anchor.hasAttribute(PROCESSED_ATTRIBUTE)) {
      continue;
    }

    const url = affiliateCandidateUrl(anchor);
    if (!url) {
      continue;
    }

    const existing = entriesByUrl.get(url);
    if (existing) {
      existing.anchors.push(anchor);
      continue;
    }

    if (entriesByUrl.size >= MAX_LINKS) {
      continue;
    }

    entriesByUrl.set(url, {
      anchor,
      anchors: [anchor],
      key: `link-${entriesByUrl.size + 1}`,
      url,
    });
  }

  return Array.from(entriesByUrl.values());
}

function sendClickBeacon(url) {
  if (!url) {
    return;
  }

  try {
    fetch(url, {
      method: "GET",
      mode: "no-cors",
      credentials: "omit",
      cache: "no-store",
      keepalive: true,
      referrerPolicy: "no-referrer",
    }).catch(() => {});
  } catch {
    // Click telemetry must never block navigation.
  }
}

function rememberOriginalPresentation(anchor) {
  if (!anchor.hasAttribute(ORIGINAL_HREF_ATTRIBUTE)) {
    anchor.setAttribute(ORIGINAL_HREF_ATTRIBUTE, anchor.href);
    anchor.setAttribute(ORIGINAL_REL_ATTRIBUTE, anchor.getAttribute("rel") || "");
    anchor.setAttribute(
      ORIGINAL_REFERRER_ATTRIBUTE,
      anchor.getAttribute("referrerpolicy") || ""
    );
  }
}

function removeBeaconHandler(anchor) {
  const handler = beaconHandlers.get(anchor);
  if (handler) {
    anchor.removeEventListener("click", handler);
    beaconHandlers.delete(anchor);
  }
}

function restoreOriginalPresentation(element) {
  element.querySelectorAll(GENERATED_SELECTOR).forEach((node) => node.remove());

  element.querySelectorAll(`a[${ORIGINAL_HREF_ATTRIBUTE}]`).forEach((anchor) => {
    removeBeaconHandler(anchor);
    anchor.href = anchor.getAttribute(ORIGINAL_HREF_ATTRIBUTE);

    const originalRel = anchor.getAttribute(ORIGINAL_REL_ATTRIBUTE) || "";
    if (originalRel) {
      anchor.setAttribute("rel", originalRel);
    } else {
      anchor.removeAttribute("rel");
    }

    const originalReferrer =
      anchor.getAttribute(ORIGINAL_REFERRER_ATTRIBUTE) || "";
    if (originalReferrer) {
      anchor.setAttribute("referrerpolicy", originalReferrer);
    } else {
      anchor.removeAttribute("referrerpolicy");
    }
  });

  element
    .querySelectorAll(`[${PROCESSED_ATTRIBUTE}]`)
    .forEach((anchor) => anchor.removeAttribute(PROCESSED_ATTRIBUTE));
}

function addIndicator(anchor, rewrite) {
  const indicator = document.createElement("span");
  indicator.className = "affiliate-resolver-link-indicator";
  indicator.dataset.affiliateResolverGenerated = "1";
  indicator.setAttribute("role", "img");
  indicator.setAttribute("aria-label", i18n("affiliate_resolver.link_indicator"));
  indicator.title = rewrite?.merchant
    ? i18n("affiliate_resolver.link_indicator_merchant", {
        merchant: rewrite.merchant,
      })
    : i18n("affiliate_resolver.link_indicator");
  indicator.textContent = "ⓘ";
  anchor.insertAdjacentElement("afterend", indicator);
}

function applyRewrite(anchor, rewrite, siteSettings) {
  if (!rewrite?.href) {
    return;
  }

  rememberOriginalPresentation(anchor);
  removeBeaconHandler(anchor);
  anchor.href = rewrite.href;
  anchor.referrerPolicy = rewrite.referrer_policy || "no-referrer";

  const rel = new Set((anchor.rel || "").split(/\s+/).filter(Boolean));
  for (const value of (rewrite.rel || "").split(/\s+/).filter(Boolean)) {
    rel.add(value);
  }
  rel.add("sponsored");
  rel.add("noopener");
  rel.add("noreferrer");
  anchor.rel = Array.from(rel).join(" ");

  if (rewrite.click_url) {
    const handler = () => sendClickBeacon(rewrite.click_url);
    beaconHandlers.set(anchor, handler);
    anchor.addEventListener("click", handler, { once: true, passive: true });
  }

  if (siteSettings.affiliate_resolver_link_indicator_enabled === true) {
    addIndicator(anchor, rewrite);
  }
}

function disclosureText(siteSettings, appliedResults) {
  const configured =
    siteSettings.affiliate_resolver_disclosure_text?.trim?.() || "";
  if (configured) {
    return configured;
  }

  return appliedResults
    .map((result) => result?.rewrite?.disclosure?.trim?.())
    .find(Boolean);
}

function addDisclosure(element, siteSettings, appliedResults) {
  if (siteSettings.affiliate_resolver_disclosure_enabled !== true) {
    return;
  }

  const text = disclosureText(siteSettings, appliedResults);
  if (!text) {
    return;
  }

  const disclosure = document.createElement("div");
  disclosure.className = "affiliate-resolver-disclosure";
  disclosure.dataset.affiliateResolverGenerated = "1";
  disclosure.setAttribute("role", "note");
  disclosure.textContent = text;
  element.appendChild(disclosure);
}

export function postFromHelper(helper) {
  return helper?.getModel?.() ?? helper?.getPost?.();
}

export function postContextKind(post) {
  const archetype =
    post?.topic?.archetype ?? post?.topic_archetype ?? post?.archetype;
  return archetype === "private_message" ? "private_message" : "public_post";
}

export function chatMessageIdFromElement(element) {
  const value = element
    ?.closest?.(".chat-message-container[data-id]")
    ?.getAttribute?.("data-id");
  const id = Number.parseInt(value, 10);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function isDomElement(value) {
  return value?.nodeType === 1 && typeof value.querySelectorAll === "function";
}

export function chatDecoratorElement(first, second) {
  if (isDomElement(first)) {
    return first;
  }
  if (isDomElement(second)) {
    return second;
  }
  return null;
}

export function chatMessageIdFromDecorator(first, second) {
  for (const candidate of [first, second]) {
    if (!candidate || isDomElement(candidate)) {
      continue;
    }

    const value = candidate.id ?? candidate.message?.id;
    const id = Number.parseInt(value, 10);
    if (Number.isSafeInteger(id) && id > 0) {
      return id;
    }
  }

  return null;
}

export function afterChatMessageMount(
  element,
  callback,
  { attempts = 4, schedule = (fn) => requestAnimationFrame(fn) } = {}
) {
  let remaining = attempts;

  const check = () => {
    const messageId = chatMessageIdFromElement(element);
    if (messageId) {
      callback(messageId);
      return;
    }

    remaining -= 1;
    if (remaining > 0) {
      schedule(check);
    }
  };

  schedule(check);
}

function sourcePayload(source) {
  if (source.type === "chat") {
    return { chat_message_id: source.id };
  }
  return { post_id: source.id };
}

function sourceContextEnabled(source, siteSettings) {
  if (source.kind === "private_message") {
    return siteSettings.affiliate_resolver_personal_messages_enabled === true;
  }
  if (source.kind === "chat") {
    return siteSettings.affiliate_resolver_chat_enabled === true;
  }
  return source.kind === "public_post";
}

function button(label, action, className = "") {
  const control = document.createElement("button");
  control.type = "button";
  control.className = `btn btn-small affiliate-resolver-control ${className}`.trim();
  control.textContent = label;
  control.addEventListener("click", action);
  return control;
}

async function updateModeratorOverride(source, operation, url) {
  return ajax("/affiliate-resolver/moderator-override.json", {
    type: "POST",
    data: {
      source_type: source.type,
      source_id: source.id,
      operation,
      ...(url ? { url } : {}),
    },
  });
}

function addLinkControl(container, entry, result, source, rerun) {
  if (!result) {
    return;
  }

  const wrapper = document.createElement("span");
  wrapper.className = "affiliate-resolver-link-control";
  wrapper.dataset.affiliateResolverGenerated = "1";

  const excluded = result.reason_code === "moderator_excluded";
  const applicable =
    result.applied === true ||
    excluded ||
    ["observed", "rewritten", "pending"].includes(result.decision);
  if (!applicable) {
    return;
  }

  const label = excluded
    ? i18n("affiliate_resolver.moderator.allow_link")
    : i18n("affiliate_resolver.moderator.keep_original");
  const operation = excluded ? "include_link" : "exclude_link";
  const control = button(label, async (event) => {
    event.preventDefault();
    event.stopPropagation();
    control.disabled = true;
    try {
      await updateModeratorOverride(source, operation, entry.url);
      await rerun();
    } catch {
      control.disabled = false;
      control.title = i18n("affiliate_resolver.moderator.action_failed");
    }
  }, "btn-flat");

  wrapper.appendChild(control);
  entry.anchor.insertAdjacentElement("afterend", wrapper);
}

function addModeratorToolbar(element, source, response, rerun) {
  const toolbar = document.createElement("div");
  toolbar.className = "affiliate-resolver-moderator-toolbar";
  toolbar.dataset.affiliateResolverGenerated = "1";
  toolbar.setAttribute("role", "group");
  toolbar.setAttribute(
    "aria-label",
    i18n("affiliate_resolver.moderator.controls")
  );

  toolbar.appendChild(
    button(i18n("affiliate_resolver.moderator.reresolve"), async () => {
      await rerun();
    })
  );

  const disabled = response?.source_disabled === true;
  const operation = disabled ? "enable_source" : "disable_source";
  const label = disabled
    ? i18n("affiliate_resolver.moderator.enable_source")
    : i18n("affiliate_resolver.moderator.disable_source");

  toolbar.appendChild(
    button(label, async (event) => {
      const control = event.currentTarget;
      control.disabled = true;
      try {
        await updateModeratorOverride(source, operation);
        await rerun();
      } catch {
        control.disabled = false;
        control.title = i18n("affiliate_resolver.moderator.action_failed");
      }
    })
  );

  element.appendChild(toolbar);
}

async function processSource(
  element,
  source,
  siteSettings,
  currentUser,
  { force = false } = {}
) {
  if (!sourceContextEnabled(source, siteSettings)) {
    return;
  }
  if (inFlightElements.has(element)) {
    return;
  }

  if (force) {
    restoreOriginalPresentation(element);
  }

  const entries = eligibleAnchors(element);
  if (!entries.length) {
    return;
  }

  inFlightElements.add(element);
  entries.forEach(({ anchors }) =>
    anchors.forEach((anchor) =>
      anchor.setAttribute(PROCESSED_ATTRIBUTE, "1")
    )
  );

  const rerun = async () => {
    restoreOriginalPresentation(element);
    await processSource(element, source, siteSettings, currentUser, {
      force: false,
    });
  };

  try {
    const response = await ajax("/affiliate-resolver/resolve.json", {
      type: "POST",
      data: {
        ...sourcePayload(source),
        links: entries.map(({ key, url }) => ({ key, url })),
      },
    });

    const results = new Map(
      (response?.results || []).map((result) => [result.key, result])
    );
    const appliedResults = [];

    for (const entry of entries) {
      const result = results.get(entry.key);
      if (result?.applied) {
        entry.anchors.forEach((anchor) =>
          applyRewrite(anchor, result.rewrite, siteSettings)
        );
        appliedResults.push(result);
      }
    }

    addDisclosure(element, siteSettings, appliedResults);

    if (
      currentUser?.staff &&
      siteSettings.affiliate_resolver_moderator_controls_enabled === true
    ) {
      for (const entry of entries) {
        addLinkControl(
          element,
          entry,
          results.get(entry.key),
          source,
          rerun
        );
      }
      addModeratorToolbar(element, source, response, rerun);
    }
  } catch {
    // Mandatory fail-open behavior: original links stay untouched.
    entries.forEach(({ anchors }) =>
      anchors.forEach((anchor) =>
        anchor.removeAttribute(PROCESSED_ATTRIBUTE)
      )
    );
  } finally {
    inFlightElements.delete(element);
  }
}

export default apiInitializer("1.0", (api) => {
  const siteSettings = api.container.lookup("service:site-settings");
  const currentUser = api.getCurrentUser();

  if (siteSettings?.affiliate_resolver_enabled !== true) {
    return;
  }

  if (
    siteSettings?.affiliate_resolver_local_staff_only === true &&
    !currentUser?.staff
  ) {
    return;
  }

  api.decorateCookedElement(
    (element, helper) => {
      const post = postFromHelper(helper);
      if (!post?.id) {
        return;
      }

      const source = {
        type: "post",
        id: post.id,
        kind: postContextKind(post),
      };
      queueMicrotask(() =>
        processSource(element, source, siteSettings, currentUser)
      );
    },
    COOKED_DECORATOR_OPTIONS
  );

  if (
    siteSettings.affiliate_resolver_chat_enabled === true &&
    typeof api.decorateChatMessage === "function"
  ) {
    api.decorateChatMessage((first, second) => {
      const element = chatDecoratorElement(first, second);
      if (!element) {
        return;
      }

      const processMessage = (messageId) =>
        processSource(
          element,
          { type: "chat", id: messageId, kind: "chat" },
          siteSettings,
          currentUser
        );

      const modelMessageId = chatMessageIdFromDecorator(first, second);
      if (modelMessageId) {
        queueMicrotask(() => processMessage(modelMessageId));
        return;
      }

      // DDecoratedHtml invokes Chat decorators while the cooked element still
      // belongs to a detached document. Wait until Glimmer has mounted it so
      // the official .chat-message-container[data-id] ancestor is available.
      afterChatMessageMount(element, processMessage);
    });
  }
});
