# frozen_string_literal: true

RSpec.describe DiscourseAffiliate::SourceContext do
  fab!(:user)

  it "classifies personal-message posts without exposing participants" do
    post = Fabricate(:private_message_post, user: user)
    context = described_class.from_post(post)

    expect(context.kind).to eq("private_message")
    expect(context.source_type).to eq("post")
    expect(context.source_id).to eq(post.id)
    expect(context.topic_id).to eq(post.topic_id)
  end

  it "derives only the category identifier from a public chat channel" do
    category = Fabricate(:category)
    channel = Struct.new(:chatable_type, :chatable_id).new("Category", category.id)
    message = Struct.new(:id, :cooked, :chat_channel).new(123, "<p>Message</p>", channel)
    context = described_class.from_chat(message)

    expect(context.kind).to eq("chat")
    expect(context.category_id).to eq(category.id)
    expect(context.topic_id).to be_nil
  end
end
