# frozen_string_literal: true

class Project < ApplicationRecord
  has_one :chat, dependent: :destroy

  enum :category, {
    web: 0, mobile: 1, data: 2, ai: 3, salesforce: 4, devops: 5, game: 6, other: 7
  }, prefix: true

  enum :level, { beginner: 0, intermediate: 1, advanced: 2 }, prefix: true
  enum :duration, { two_weeks: 0, one_month: 1, three_months: 2, flexible: 3 }, prefix: true
  enum :status, { draft: 0, published: 1 }, prefix: true

  validates :title, :category, :level, :duration, :max_team_members,
            :short_description, :full_description, presence: true

  validates :short_description, length: { maximum: 150 }

  validates :max_team_members,
            numericality: { only_integer: true, greater_than_or_equal_to: 2, less_than_or_equal_to: 10 }

  # Si tu as des colonnes JSON/Array qui peuvent être nil en DB, ça aide :
  def tech_stack_list = Array(tech_stack)
  def team_roles_list = Array(team_roles)
  def objectives_list = Array(objectives)
  def timeline_list   = Array(timeline)
end
