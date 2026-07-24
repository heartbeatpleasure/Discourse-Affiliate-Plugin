# frozen_string_literal: true

module ::DiscourseAffiliate
  SourceContext = Struct.new(
    :record,
    :source_type,
    :source_id,
    :kind,
    :cooked,
    :category_id,
    :topic_id,
    keyword_init: true,
  ) do
    class << self
      def from_post(post)
        kind = post.topic.archetype == Archetype.private_message ? "private_message" : "public_post"

        new(
          record: post,
          source_type: "post",
          source_id: post.id,
          kind: kind,
          cooked: post.cooked,
          category_id: post.topic.category_id,
          topic_id: post.topic_id,
        )
      end

      def from_chat(message)
        channel = message.chat_channel
        category_id = channel.chatable_id if channel.chatable_type == "Category"

        new(
          record: message,
          source_type: "chat",
          source_id: message.id,
          kind: "chat",
          cooked: message.cooked,
          category_id: category_id,
          topic_id: nil,
        )
      end
    end
  end
end
