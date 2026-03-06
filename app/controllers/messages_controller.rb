# frozen_string_literal: true

class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project
  before_action :set_chat

  def create
    user_content = message_params[:content].to_s.strip

    if user_content.blank?
      respond_to do |format|
        format.turbo_stream do
          redirect_to project_chat_path(@project), alert: "Message vide."
        end
        format.html do
          redirect_to project_chat_path(@project), alert: "Message vide."
        end
      end
      return
    end

    @chat.messages.create!(role: "user", content: user_content)

    payload = Codi::ProjectRefiner.new(project: @project, chat: @chat).call

    @chat.messages.create!(
      role: "assistant",
      content: JSON.pretty_generate(payload)
    )

    @project.update!(
      full_description: payload["full_description"].presence || @project.full_description,
      tech_stack: payload["tech_stack"],
      team_roles: payload["team_roles"],
      objectives: payload["objectives"],
      timeline: payload["timeline"]
    )

    @message = Message.new

    respond_to do |format|
      format.turbo_stream
      format.html do
        redirect_to project_chat_path(@project), notice: "Codi a mis à jour le projet."
      end
    end
  rescue StandardError => e
    Rails.logger.error("[MessagesController#create] #{e.class}: #{e.message}")

    respond_to do |format|
      format.turbo_stream do
        redirect_to project_chat_path(@project), alert: "Erreur pendant la réponse de Codi."
      end
      format.html do
        redirect_to project_chat_path(@project), alert: "Erreur pendant la réponse de Codi."
      end
    end
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
end
