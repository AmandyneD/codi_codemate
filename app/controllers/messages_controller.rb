class MessagesController < ApplicationController
  def create
    @project = Project.find(params[:project_id])
    @chat = @project.chat || @project.create_chat

    @chat.messages.create!(
      role: "user",
      content: params.require(:message).fetch(:content)
    )

    Codi::ProjectRefiner.new(project: @project, chat: @chat).call

    redirect_to chat_project_path(@project)
  rescue => e
    Rails.logger.error("[CODI] chat error: #{e.class} #{e.message}")
    redirect_to chat_project_path(@project), alert: "Codi n'a pas pu répondre."
  end
end
