# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::PostLinkExtractor do
  it "returns external HTTPS links but excludes quotes, oneboxes, and internal links" do
    cooked = <<~HTML
      <p><a href="https://merchant.example/product">Product</a></p>
      <blockquote><a href="https://merchant.example/quoted">Quoted</a></blockquote>
      <aside class="onebox"><a href="https://merchant.example/onebox">Onebox</a></aside>
      <p><a href="#{Discourse.base_url}/t/topic/1">Internal</a></p>
    HTML

    expect(described_class.new(cooked).eligible_urls.to_a).to eq([
      "https://merchant.example/product",
    ])
  end
end
