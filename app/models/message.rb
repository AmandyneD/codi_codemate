# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat

  validates :role, inclusion: { in: %w[system user assistant] }
  validates :content, presence: true
end
