import { module, test } from "qunit";
import {
  afterChatMessageMount,
  affiliateCandidateUrl,
  chatDecoratorElement,
  chatMessageIdFromDecorator,
  chatMessageIdFromElement,
  COOKED_DECORATOR_OPTIONS,
  postContextKind,
  postFromHelper,
  sourceContextEnabled,
} from "discourse/plugins/Discourse-Affiliate-Plugin/discourse/api-initializers/discourse-affiliate";

module("Unit | Affiliate Resolver | cooked decorator", function () {
  test("uses the current post-stream model accessor", function (assert) {
    const post = { id: 203 };

    assert.strictEqual(
      postFromHelper({
        getModel: () => post,
        getPost: () => ({ id: 999 }),
      }),
      post
    );
  });

  test("keeps a compatibility fallback for older helpers", function (assert) {
    const post = { id: 203 };

    assert.strictEqual(postFromHelper({ getPost: () => post }), post);
  });

  test("classifies personal messages independently from public posts", function (assert) {
    assert.strictEqual(
      postContextKind({ topic: { archetype: "private_message" } }),
      "private_message"
    );
    assert.strictEqual(
      postContextKind({ topic: { archetype: "regular" } }),
      "public_post"
    );
  });

  test(
    "keeps each content context independently switchable",
    function (assert) {
      const settings = {
        affiliate_resolver_public_posts_enabled: true,
        affiliate_resolver_personal_messages_enabled: false,
        affiliate_resolver_chat_enabled: false,
      };

      assert.true(
        sourceContextEnabled({ kind: "public_post" }, settings),
        "public posts preserve the existing enabled default"
      );
      assert.true(
        sourceContextEnabled({ kind: "public_post" }, {}),
        "an older cached client setting payload preserves public-post behaviour"
      );
      assert.false(
        sourceContextEnabled({ kind: "private_message" }, settings),
        "personal messages remain independently disabled"
      );
      assert.false(
        sourceContextEnabled({ kind: "chat" }, settings),
        "Chat remains independently disabled"
      );

      settings.affiliate_resolver_public_posts_enabled = false;
      settings.affiliate_resolver_personal_messages_enabled = true;
      settings.affiliate_resolver_chat_enabled = true;

      assert.false(
        sourceContextEnabled({ kind: "public_post" }, settings),
        "public posts can be disabled without disabling private contexts"
      );
      assert.true(sourceContextEnabled({ kind: "private_message" }, settings));
      assert.true(sourceContextEnabled({ kind: "chat" }, settings));
      assert.false(sourceContextEnabled({ kind: "preview" }, settings));
    }
  );

  test(
    "uses the original onebox URL only for matching onebox links",
    function (assert) {
      const onebox = document.createElement("aside");
      onebox.className = "onebox";
      onebox.dataset.oneboxSrc = "https://merchant.example/product";

      const title = document.createElement("a");
      title.href = "https://merchant.example/product";
      onebox.appendChild(title);

      const author = document.createElement("a");
      author.href = "https://author.example/profile";
      onebox.appendChild(author);

      assert.strictEqual(
        affiliateCandidateUrl(title),
        "https://merchant.example/product"
      );
      assert.strictEqual(affiliateCandidateUrl(author), null);
    }
  );

  test("keeps ordinary external links eligible", function (assert) {
    const anchor = document.createElement("a");
    anchor.href = "https://merchant.example/product";

    assert.strictEqual(
      affiliateCandidateUrl(anchor),
      "https://merchant.example/product"
    );
  });

  test(
    "reads the persisted chat message id from the official message container",
    function (assert) {
      const wrapper = document.createElement("div");
      wrapper.className = "chat-message-container";
      wrapper.dataset.id = "412";
      const cooked = document.createElement("div");
      wrapper.appendChild(cooked);

      assert.strictEqual(chatMessageIdFromElement(cooked), 412);
    }
  );

  test(
    "waits for detached Chat cooked HTML to be mounted before reading its id",
    function (assert) {
      const scheduled = [];
      const cooked = document.createElement("div");
      let resolvedId = null;

      afterChatMessageMount(cooked, (id) => (resolvedId = id), {
        schedule: (callback) => scheduled.push(callback),
      });

      assert.strictEqual(resolvedId, null, "the detached element has no id yet");
      assert.strictEqual(scheduled.length, 1, "a post-render check is scheduled");

      const wrapper = document.createElement("div");
      wrapper.className = "chat-message-container";
      wrapper.dataset.id = "413";
      wrapper.appendChild(cooked);
      scheduled.shift()();

      assert.strictEqual(resolvedId, 413, "the id is read after mounting");
    }
  );

  test(
    "supports both current and legacy Chat decorator signatures",
    function (assert) {
      const cooked = document.createElement("div");
      const container = document.createElement("div");

      assert.strictEqual(chatDecoratorElement(cooked, {}), cooked);
      assert.strictEqual(chatDecoratorElement({ id: 414 }, container), container);
      assert.strictEqual(
        chatMessageIdFromDecorator({ id: 414 }, container),
        414
      );
      assert.strictEqual(
        chatMessageIdFromDecorator({ message: { id: 415 } }, container),
        415
      );
    }
  );

  test("is restricted to the topic post stream", function (assert) {
    assert.deepEqual(COOKED_DECORATOR_OPTIONS, {
      id: "discourse-affiliate-resolver",
      onlyStream: true,
    });
  });
});
