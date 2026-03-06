class MessagesController < ApplicationController
  before_action :set_project
  before_action :set_chat

  def create
    user_content = params.require(:message).fetch(:content).to_s.strip

    if user_content.blank?
      redirect_to project_chat_path(@project), alert: "Message vide."
      return
    end

    @chat.messages.create!(role: "user", content: user_content)

    payload = Codi::ProjectRefiner.new(project: @project, chat: @chat).call

    # On enregistre la réponse assistant (on stocke le JSON pour historique)
    @chat.messages.create!(role: "assistant", content: JSON.pretty_generate(payload))

    # Et on met à jour le project directement => effet “refine”
    @project.update!(
      full_description: payload["full_description"].presence || @project.full_description,
      tech_stack: payload["tech_stack"],
      team_roles: payload["team_roles"],
      objectives: payload["objectives"],
      timeline: payload["timeline"]
    )

    redirect_to project_chat_path(@project), notice: "Codi a mis à jour le projet."
  rescue => e
    Rails.logger.error("[MessagesController#create] #{e.class}: #{e.message}")
    redirect_to project_chat_path(@project), alert: "Erreur pendant la réponse de Codi."
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def set_chat
    @chat = @project.chat || @project.create_chat!
  end
end
