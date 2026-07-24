# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::ModeratorOverrideStore do
  fab!(:post)

  it "stores only a hash when a link is excluded" do
    store = described_class.new(post)
    url = "https://merchant.example/product?color=red"

    store.exclude_link!(url)
    post.reload

    stored = post.custom_fields.fetch(described_class::EXCLUDED_LINK_HASHES_FIELD)
    expect(stored).not_to include("merchant.example")
    expect(store.link_excluded?(url)).to eq(true)

    store.include_link!(url)
    expect(store.link_excluded?(url)).to eq(false)
  end

  it "can disable and re-enable a complete source" do
    store = described_class.new(post)

    store.disable_source!
    expect(store.source_disabled?).to eq(true)

    store.enable_source!
    expect(store.source_disabled?).to eq(false)
  end
end
