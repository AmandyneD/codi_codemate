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

    project_updates = build_project_updates(payload)
    @project.update!(project_updates)

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

  def build_project_updates(payload)
    {
      full_description: normalized_text(payload["full_description"]) || @project.full_description,
      tech_stack: normalized_array(payload["tech_stack"]) || Array(@project.tech_stack),
      team_roles: normalized_array(payload["team_roles"]) || Array(@project.team_roles),
      objectives: normalized_array(payload["objectives"]) || Array(@project.objectives),
      timeline: normalized_array(payload["timeline"]) || Array(@project.timeline)
    }
  end

  def normalized_text(value)
    text = value.to_s.strip
    text.presence
  end

  def normalized_array(value)
    case value
    when nil
      nil
    when Array
      cleaned = value.map { |item| item.to_s.strip }.reject(&:blank?).uniq
      cleaned.presence
    when String
      cleaned = value.split(/\r?\n|,/).map(&:strip).reject(&:blank?).uniq
      cleaned.presence
    else
      nil
    end
  end
end
