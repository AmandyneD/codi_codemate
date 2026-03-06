# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat

  validates :role, inclusion: { in: %w[system user assistant] }
  validates :content, presence: true

  after_create_commit :broadcast_message, unless: :system?

  private

  def system?
    role == "system"
  end

  def broadcast_message
    html = ApplicationController.render(
      partial: "messages/message",
      locals: { message: self }
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "chat_#{chat.id}_messages",
      target: "messages",
      html: html
    )
  end
end
