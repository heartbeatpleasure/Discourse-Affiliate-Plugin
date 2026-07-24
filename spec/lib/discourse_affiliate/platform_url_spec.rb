# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::PlatformUrl do
  after do
    SiteSetting.affiliate_resolver_platform_base_url = ""
  end

  it "accepts an HTTPS origin without exposing a path" do
    SiteSetting.affiliate_resolver_platform_base_url = "https://affiliate-test.example/"

    expect(described_class.base.to_s).to eq("https://affiliate-test.example")
    expect(described_class.status).to include(
      configured: true,
      error_code: nil,
      scheme: "https",
      secure: true,
    )
  end

  it "rejects HTTP because the bearer token must not be sent unencrypted" do
    SiteSetting.affiliate_resolver_platform_base_url = "http://affiliate-test.example"

    expect(described_class.status).to include(
      configured: false,
      error_code: "https_required",
      scheme: "http",
      secure: false,
    )
    expect { described_class.base }.to raise_error(
      DiscourseAffiliate::PlatformUrl::Invalid,
      "https_required",
    )
  end

  it "rejects paths and credentials" do
    SiteSetting.affiliate_resolver_platform_base_url =
      "https://user:password@affiliate-test.example/admin"

    expect(described_class.status[:configured]).to eq(false)
    expect(described_class.status[:error_code]).to eq("credentials_not_allowed")
  end
end
