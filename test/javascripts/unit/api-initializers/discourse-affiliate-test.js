import { module, test } from "qunit";
import {
  affiliateCandidateUrl,
  chatMessageIdFromElement,
  COOKED_DECORATOR_OPTIONS,
  postContextKind,
  postFromHelper,
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

  test("is restricted to the topic post stream", function (assert) {
    assert.deepEqual(COOKED_DECORATOR_OPTIONS, {
      id: "discourse-affiliate-resolver",
      onlyStream: true,
    });
  });
});
