# frozen_string_literal: true

class Message < ApplicationRecord
  belongs_to :chat

  ROLES = %w[system user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true
end
