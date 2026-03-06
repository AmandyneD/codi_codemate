# frozen_string_literal: true

class ChatsController < ApplicationController
  before_action :authenticate_user!
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
      role: "assistant",
      content: initial_context_message(project)
    )

    chat
  end

  def initial_context_message(project)
    <<~TEXT
      Bonjour, j’ai bien récupéré le contexte de ton projet.

      **Titre :** #{project.title}
      **Catégorie :** #{project.category.to_s.humanize}
      **Niveau :** #{project.level.to_s.humanize}
      **Durée :** #{project.duration.to_s.humanize}

      **Description actuelle :**
      #{project.full_description.presence || project.short_description.presence || "Aucune description fournie pour le moment."}

      Tu peux maintenant me demander d’affiner le projet :
      - modifier la stack technique
      - rendre la description plus claire
      - ajouter des rôles dans l’équipe
      - préciser les objectifs
      - structurer la timeline
    TEXT
  end
end
