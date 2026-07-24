# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::ModeratorOverridesController do
  fab!(:admin)
  fab!(:post)

  before do
    SiteSetting.affiliate_resolver_enabled = true
    SiteSetting.affiliate_resolver_moderator_controls_enabled = true
    sign_in(admin)
  end

  it "disables and enables a visible source without changing post raw content" do
    original_raw = post.raw

    post "/affiliate-resolver/moderator-override.json",
         params: {
           source_type: "post",
           source_id: post.id,
           operation: "disable_source",
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["source_disabled"]).to eq(true)
    expect(post.reload.raw).to eq(original_raw)

    post "/affiliate-resolver/moderator-override.json",
         params: {
           source_type: "post",
           source_id: post.id,
           operation: "enable_source",
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["source_disabled"]).to eq(false)
  end

  it "stores a link exclusion without storing its raw URL" do
    url = "https://merchant.example/product"

    post "/affiliate-resolver/moderator-override.json",
         params: {
           source_type: "post",
           source_id: post.id,
           operation: "exclude_link",
           url: url,
         }

    expect(response.status).to eq(200)
    expect(response.parsed_body["link_excluded"]).to eq(true)
    stored = post.reload.custom_fields.fetch(
      DiscourseAffiliate::ModeratorOverrideStore::EXCLUDED_LINK_HASHES_FIELD,
    )
    expect(stored).not_to include(url)
  end

  it "rejects non-staff users" do
    sign_in(Fabricate(:user))

    post "/affiliate-resolver/moderator-override.json",
         params: {
           source_type: "post",
           source_id: post.id,
           operation: "disable_source",
         }

    expect(response.status).to eq(403)
  end
end
