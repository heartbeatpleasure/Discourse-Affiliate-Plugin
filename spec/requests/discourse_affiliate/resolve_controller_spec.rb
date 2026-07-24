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
end
