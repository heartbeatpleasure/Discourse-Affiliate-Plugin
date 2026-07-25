# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::PostLinkExtractor do
  it "returns external HTTPS links and the original source of eligible oneboxes" do
    cooked = <<~HTML
      <p><a href="https://merchant.example/product">Product</a></p>
      <aside class="onebox" data-onebox-src="https://merchant.example/onebox">
        <header class="source">
          <a href="https://merchant.example/onebox">merchant.example</a>
        </header>
        <article class="onebox-body">
          <a href="https://merchant.example/onebox">Product title</a>
          <a href="https://author.example/profile">Author profile</a>
        </article>
      </aside>
      <p><a href="#{Discourse.base_url}/t/topic/1">Internal</a></p>
    HTML

    expect(described_class.new(cooked).eligible_urls.to_a).to eq([
      "https://merchant.example/product",
      "https://merchant.example/onebox",
    ])
  end

  it "keeps quoted and internal oneboxes excluded" do
    cooked = <<~HTML
      <blockquote>
        <a href="https://merchant.example/quoted-link">Quoted link</a>
        <aside class="onebox" data-onebox-src="https://merchant.example/quoted">
          <a href="https://merchant.example/quoted">Quoted onebox</a>
        </aside>
      </blockquote>
      <aside class="onebox" data-onebox-src="#{Discourse.base_url}/t/topic/1">
        <a href="#{Discourse.base_url}/t/topic/1">Internal onebox</a>
      </aside>
    HTML

    expect(described_class.new(cooked).eligible_urls).to be_empty
  end
end
