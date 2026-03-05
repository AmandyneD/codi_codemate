class PagesController < ApplicationController
  def home
  end

  def chat
  @project = Project.find(params[:id])
  @chat = @project.chat || @project.create_chat
  @messages = @chat.messages.order(:created_at)
  @message = @chat.messages.new
  end
end
