# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_chat

  def create
    user_content = message_params[:content].to_s.strip

    if user_content.blank?
      redirect_to project_chat_path(@project), alert: "Message vide."
      return
    end

    @chat.messages.create!(role: "user", content: user_content)

    payload = Codi::ProjectRefiner.new(project: @project, chat: @chat).call

    @chat.messages.create!(
      role: "assistant",
      content: JSON.pretty_generate(payload)
    )

    safe_updates = build_safe_project_updates(payload)
    @project.update!(safe_updates) if safe_updates.any?

    redirect_to project_chat_path(@project), notice: "Codi a mis à jour le projet."
  rescue StandardError => e
    Rails.logger.error("[MessagesController#create] #{e.class}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace

    redirect_to project_chat_path(@project), alert: "Erreur pendant la réponse de Codi."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_chat
    @chat = @project.chat || @project.create_chat!
  end

  def message_params
    params.require(:message).permit(:content)
  end

  def build_safe_project_updates(payload)
    updates = {}

    full_description = normalized_text(payload["full_description"])
    tech_stack       = normalized_array(payload["tech_stack"])
    team_roles       = normalized_array(payload["team_roles"])
    objectives       = normalized_array(payload["objectives"])
    timeline         = normalized_array(payload["timeline"])

    updates[:full_description] = full_description if full_description.present?

    updates[:tech_stack] = merge_array_field(@project.tech_stack, tech_stack)
    updates[:team_roles] = merge_array_field(@project.team_roles, team_roles)
    updates[:objectives] = merge_array_field(@project.objectives, objectives)
    updates[:timeline]   = merge_array_field(@project.timeline, timeline)

    updates.compact_blank
  end

  def normalized_text(value)
    return nil if value.nil?

    text = value.is_a?(String) ? value.strip : value.to_s.strip
    text.presence
  end

  def normalized_array(value)
    case value
    when nil
      nil
    when Array
      cleaned = value.map { |item| item.to_s.strip }.reject(&:blank?)
      cleaned.presence
    when String
      cleaned = value.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
      cleaned.presence
    else
      nil
    end
  end

  def merge_array_field(existing, incoming)
    existing_clean = Array(existing).map { |item| item.to_s.strip }.reject(&:blank?)
    incoming_clean = Array(incoming).map { |item| item.to_s.strip }.reject(&:blank?)

    return existing_clean if incoming_clean.blank?
    return incoming_clean if existing_clean.blank?

    # Si Codi renvoie une version plus complète, on la prend telle quelle
    return incoming_clean if incoming_clean.length >= existing_clean.length

    # Si Codi renvoie une réponse partielle (ex: juste ["Python"]),
    # on l’ajoute à l’existant sans perdre les autres éléments.
    (incoming_clean + existing_clean).uniq
  end
end
