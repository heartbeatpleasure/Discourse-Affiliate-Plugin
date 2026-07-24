import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

const MAX_LINKS = 50;
const PROCESSED_ATTRIBUTE = "data-affiliate-resolver-processed";
export const COOKED_DECORATOR_OPTIONS = {
  id: "discourse-affiliate-resolver",
  onlyStream: true,
};

const EXCLUDED_SELECTOR = [
  "aside.onebox a",
  ".onebox a",
  "blockquote a",
  ".quote a",
  "a.mention",
  "a.mention-group",
  "a.hashtag-cooked",
  "a.lightbox",
  "a.attachment",
].join(",");

function externalHttpsUrl(anchor) {
  try {
    const url = new URL(anchor.href, window.location.origin);
    if (url.protocol !== "https:" || url.origin === window.location.origin) {
      return null;
    }
    return url.href;
  } catch {
    return null;
  }
}

function eligibleAnchors(element) {
  return Array.from(element.querySelectorAll("a[href]"))
    .filter((anchor) => !anchor.matches(EXCLUDED_SELECTOR))
    .filter((anchor) => !anchor.hasAttribute(PROCESSED_ATTRIBUTE))
    .map((anchor, index) => ({
      anchor,
      key: `link-${index + 1}`,
      url: externalHttpsUrl(anchor),
    }))
    .filter((entry) => entry.url)
    .slice(0, MAX_LINKS);
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

function applyRewrite(anchor, rewrite) {
  if (!rewrite?.href) {
    return;
  }

  anchor.href = rewrite.href;
  anchor.referrerPolicy = rewrite.referrer_policy || "no-referrer";

  const rel = new Set((anchor.rel || "").split(/\s+/).filter(Boolean));
  rel.add("sponsored");
  rel.add("noopener");
  rel.add("noreferrer");
  anchor.rel = Array.from(rel).join(" ");

  if (rewrite.click_url) {
    anchor.addEventListener(
      "click",
      () => sendClickBeacon(rewrite.click_url),
      { once: true, passive: true }
    );
  }
}

export function postFromHelper(helper) {
  return helper?.getModel?.() ?? helper?.getPost?.();
}

async function processPost(element, post) {
  const entries = eligibleAnchors(element);
  if (!entries.length) {
    return;
  }

  entries.forEach(({ anchor }) => anchor.setAttribute(PROCESSED_ATTRIBUTE, "1"));

  try {
    const response = await ajax("/affiliate-resolver/resolve.json", {
      type: "POST",
      data: {
        post_id: post.id,
        links: entries.map(({ key, url }) => ({ key, url })),
      },
    });

    const byKey = new Map(entries.map((entry) => [entry.key, entry.anchor]));
    for (const result of response?.results || []) {
      if (!result?.applied) {
        continue;
      }
      const anchor = byKey.get(result.key);
      if (anchor) {
        applyRewrite(anchor, result.rewrite);
      }
    }
  } catch {
    // Mandatory fail-open behavior: original links stay untouched.
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

      queueMicrotask(() => processPost(element, post));
    },
    COOKED_DECORATOR_OPTIONS
  );
});
