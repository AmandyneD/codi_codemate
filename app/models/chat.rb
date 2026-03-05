# frozen_string_literal: true

class Chat < ApplicationRecord
  belongs_to :project
  has_many :messages, dependent: :destroy

  # pratique : récupérer le dernier message user
  def last_user_message
    messages.where(role: "user").order(:created_at).last
  end
end
