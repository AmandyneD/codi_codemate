class ChatsController < ApplicationController
  before_action :set_project

  def show
    @chat = @project.chat || build_chat_with_seed_messages(@project)
    @messages = @chat.messages.order(:created_at)
    @message = Message.new
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def build_chat_with_seed_messages(project)
    chat = project.create_chat!

    chat.messages.create!(
      role: "system",
      content: Codi::ProjectRefiner.system_prompt
    )

    chat.messages.create!(
      role: "user",
      content: Codi::ProjectRefiner.seed_user_prompt(project)
    )

    chat
  end
end
