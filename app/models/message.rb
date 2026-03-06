# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat

  validates :role, inclusion: { in: %w[system user assistant] }
  validates :content, presence: true

  after_create_commit :broadcast_message

  private

  def broadcast_message
    broadcast_append_to(
      "chat_#{chat.id}_messages",
      target: "messages",
      partial: "messages/message",
      locals: { message: self }
    )
  end
end
