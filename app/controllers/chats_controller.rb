# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_project

  def show
    @chat = @project.chat || @project.create_chat!
    ensure_seed_messages!(@chat, @project)

    @messages = @chat.messages.order(:created_at)
    @message = Message.new
  end

  private

  def set_project
    @project = Project.find(params[:project_id])
  end

  def ensure_seed_messages!(chat, project)
    unless chat.messages.exists?(role: "system")
      chat.messages.create!(
        role: "system",
        content: Codi::ProjectRefiner.system_prompt
      )
    end

    unless chat.messages.where(role: "assistant").where("content LIKE ?", "[CONTEXTE PROJET]%").exists?
      chat.messages.create!(
        role: "assistant",
        content: initial_context_message(project)
      )
    end
  end

  def initial_context_message(project)
    <<~TEXT
      [CONTEXTE PROJET]

      Bonjour, j’ai bien récupéré le contexte initial de ton projet.

      Titre : #{project.title}
      Catégorie : #{project.category.to_s.humanize}
      Niveau : #{project.level.to_s.humanize}
      Durée : #{project.duration.to_s.humanize}

      Description de départ :
      #{project.short_description.presence || project.full_description.presence || "Aucune description fournie pour le moment."}

      Tu peux maintenant me demander par exemple :
      - de changer la stack technique
      - de reformuler la description
      - d’ajouter des rôles d’équipe
      - de préciser les objectifs
      - de structurer la timeline
    TEXT
  end
end
