# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::ResolveController do
  fab!(:user)
  fab!(:topic)
  fab!(:post) do
    Fabricate(:post, topic: topic, cooked: '<p><a href="https://merchant.example/product">Product</a></p>')
  end

  before do
    SiteSetting.affiliate_resolver_enabled = true
    SiteSetting.affiliate_resolver_local_staff_only = false
    sign_in(user)
  end

  it "fails open when rules are unavailable" do
    DiscourseAffiliate::RulesCache.stubs(:current).returns(nil)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: post.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["results"]).to eq([])
    expect(response.parsed_body["reason"]).to eq("rules_unavailable")
  end

  it "does not process private messages" do
    message = Fabricate(:private_message_post, user: user)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: message.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["reason"]).to eq("private_context")
  end

  it "applies the platform rewritten decision when local safeguards allow it" do
    SiteSetting.affiliate_resolver_local_observe_only = false
    DiscourseAffiliate::RulesCache.stubs(:current).returns(
      {
        "payload" => {
          "enabled" => true,
          "observe_only" => false,
          "rules" => [
            {
              "host" => "merchant.example",
              "include_subdomains" => false,
              "path_exclusions" => [],
              "query_allowlist" => [],
              "query_denylist" => [],
              "affiliate_parameters" => ["aff"],
              "allowed_contexts" => ["public_post"],
              "allowed_category_ids" => [],
              "excluded_category_ids" => [],
              "staff_only" => false,
              "observe_only" => false,
              "rollout_percentage" => 100,
              "priority" => 100,
            },
          ],
        },
      },
    )

    fake_client = Object.new
    fake_client.define_singleton_method(:resolve) do |payload|
      {
        body: {
          "request_id" => payload[:request_id],
          "results" => [
            {
              "key" => "link-1",
              "decision" => "rewritten",
              "reason_code" => "mapping_approved",
              "rewrite" => {
                "href" => "https://affiliate.example/go/test-route",
                "external" => false,
                "click_url" => nil,
                "referrer_policy" => "no-referrer",
              },
            },
          ],
        },
        http_status: 200,
      }
    end
    DiscourseAffiliate::PlatformClient.stubs(:new).returns(fake_client)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: post.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    result = response.parsed_body.fetch("results").first
    expect(result["decision"]).to eq("rewritten")
    expect(result["applied"]).to eq(true)
    expect(result.dig("rewrite", "href")).to eq("https://affiliate.example/go/test-route")
  end
end
