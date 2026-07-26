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

  it "normalizes indexed browser form parameters" do
    raw =
      ActionController::Parameters.new(
        "0" => {
          "key" => "link-1",
          "url" => "https://merchant.example/product",
        },
      )

    normalized = described_class.new.send(:normalize_links, raw)

    expect(normalized).to eq(
      [{ key: "link-1", url: "https://merchant.example/product" }],
    )
  end

  it "keeps public posts enabled by default for backwards compatibility" do
    DiscourseAffiliate::RulesCache.stubs(:current).returns(nil)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: post.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["reason"]).to eq("rules_unavailable")
  end

  it "allows public posts to be disabled independently" do
    SiteSetting.affiliate_resolver_public_posts_enabled = false

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: post.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["reason"]).to eq("context_disabled")
    expect(response.parsed_body["results"]).to eq([])
  end

  it "keeps personal messages disabled by default" do
    message = Fabricate(:private_message_post, user: user)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: message.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["reason"]).to eq("context_disabled")
  end

  it "sends an explicitly enabled personal-message context without participant data" do
    SiteSetting.affiliate_resolver_personal_messages_enabled = true
    message = Fabricate(
      :private_message_post,
      user: user,
      cooked: '<p><a href="https://merchant.example/product">Product</a></p>',
    )
    rules_for(%w[private_message])
    captured_payload = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:resolve) do |payload|
      captured_payload = payload
      {
        body: {
          "request_id" => payload[:request_id],
          "results" => [
            {
              "key" => "link-1",
              "decision" => "observed",
              "reason_code" => "observe_only",
              "rewrite" => nil,
            },
          ],
        },
        http_status: 200,
      }
    end
    DiscourseAffiliate::PlatformClient.stubs(:new).returns(fake_client)

    post "/affiliate-resolver/resolve.json",
         params: {
           post_id: message.id,
           links: [{ key: "link-1", url: "https://merchant.example/product" }],
         }

    expect(response.status).to eq(200)
    expect(captured_payload.dig(:context, :kind)).to eq("private_message")
    expect(captured_payload[:context].keys).not_to include(
      :username,
      :participants,
      :post_text,
      :topic_id,
    )
    expect(captured_payload.dig(:context, :source_ref_hash)).to match(/\A[a-f0-9]{64}\z/)
  end

  it "applies the platform rewritten decision when local safeguards allow it" do
    SiteSetting.affiliate_resolver_local_observe_only = false
    rules_for(%w[public_post])

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
                "rel" => "nofollow ugc sponsored noreferrer noopener",
                "merchant" => "Example merchant",
                "disclosure" => "Affiliate link",
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
    expect(response.parsed_body["reason"]).to eq("success")
    result = response.parsed_body.fetch("results").first
    expect(result["decision"]).to eq("rewritten")
    expect(result["applied"]).to eq(true)
    expect(result.dig("rewrite", "href")).to eq("https://affiliate.example/go/test-route")
    expect(result.dig("rewrite", "merchant")).to eq("Example merchant")
    expect(result.dig("rewrite", "disclosure")).to eq("Affiliate link")
  end

  private

  def rules_for(contexts)
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
              "allowed_contexts" => contexts,
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
  end
end
