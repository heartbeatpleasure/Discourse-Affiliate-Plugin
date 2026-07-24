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

  it "matches only the exact reviewed context rule" do
    matcher = described_class.new(
      payload: payload,
      context_kind: "public_post",
      category_id: 12,
      staff: true,
      cohort: 0,
    )
    expect(matcher.match("https://merchant.example/products/1?color=red")).to be_present
    expect(matcher.match("https://lookalike-merchant.example/products/1")).to be_nil
    expect(matcher.match("https://merchant.example/account")).to be_nil
    expect(matcher.match("https://merchant.example/products/1?aff=existing")).to be_nil
  end

  it "requires personal messages and chat to be explicitly allowed" do
    private_matcher = described_class.new(
      payload: payload,
      context_kind: "private_message",
      category_id: nil,
      staff: true,
      cohort: 0,
    )
    expect(private_matcher.match("https://merchant.example/products/1?color=red")).to be_nil

    payload["rules"][0]["allowed_contexts"] = %w[public_post private_message chat]
    payload["rules"][0]["allowed_category_ids"] = []

    expect(private_matcher.match("https://merchant.example/products/1?color=red")).to be_present
    chat_matcher = described_class.new(
      payload: payload,
      context_kind: "chat",
      category_id: nil,
      staff: true,
      cohort: 0,
    )
    expect(chat_matcher.match("https://merchant.example/products/1?color=red")).to be_present
  end

  it "allows staff through a zero-percent rollout while keeping members outside it" do
    payload["rules"][0]["rollout_percentage"] = 0

    staff_matcher = described_class.new(
      payload: payload,
      context_kind: "public_post",
      category_id: 12,
      staff: true,
      cohort: 99,
    )
    member_matcher = described_class.new(
      payload: payload,
      context_kind: "public_post",
      category_id: 12,
      staff: false,
      cohort: 0,
    )

    expect(staff_matcher.match("https://merchant.example/products/1?color=red")).to be_present
    expect(member_matcher.match("https://merchant.example/products/1?color=red")).to be_nil
  end
end
