# frozen_string_literal: true

class Chat < ApplicationRecord
  belongs_to :project
  has_many :messages, dependent: :destroy
end
