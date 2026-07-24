import { module, test } from "qunit";
import {
  COOKED_DECORATOR_OPTIONS,
  postFromHelper,
} from "discourse/plugins/Discourse-Affiliate-Resolver/discourse/api-initializers/discourse-affiliate";

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

  test("is restricted to the topic post stream", function (assert) {
    assert.deepEqual(COOKED_DECORATOR_OPTIONS, {
      id: "discourse-affiliate-resolver",
      onlyStream: true,
    });
  });
});
