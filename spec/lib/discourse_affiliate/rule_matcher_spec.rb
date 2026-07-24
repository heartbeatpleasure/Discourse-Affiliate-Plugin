# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::RuleMatcher do
  let(:payload) do
    {
      "enabled" => true,
      "observe_only" => true,
      "rules" => [
        {
          "host" => "merchant.example",
          "include_subdomains" => false,
          "path_exclusions" => ["/account"],
          "query_allowlist" => ["color"],
          "query_denylist" => ["token"],
          "affiliate_parameters" => ["aff"],
          "allowed_contexts" => ["public_post"],
          "allowed_category_ids" => [12],
          "excluded_category_ids" => [],
          "staff_only" => true,
          "observe_only" => true,
          "rollout_percentage" => 100,
          "priority" => 10,
        },
      ],
    }
  end

  it "matches only the exact reviewed public-post rule" do
    matcher = described_class.new(payload: payload, category_id: 12, staff: true, cohort: 0)
    expect(matcher.match("https://merchant.example/products/1?color=red")).to be_present
    expect(matcher.match("https://lookalike-merchant.example/products/1")).to be_nil
    expect(matcher.match("https://merchant.example/account")).to be_nil
    expect(matcher.match("https://merchant.example/products/1?aff=existing")).to be_nil
  end
end
