# frozen_string_literal: true

class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :publish ]

  def index
    @projects = Project.status_published.order(created_at: :desc)
  end

  def new
    @project = Project.new(max_team_members: 5)
  end

  def chat
    @project = Project.find(params[:id])
    @chat = @project.chat || @project.create_chat
    @messages = @chat.messages.order(:created_at)
    @message = @chat.messages.new
  end

  def create
    @project = Project.new(project_params)
    @project.status = :draft

    unless @project.save
      return render :new, status: :unprocessable_entity
    end


    begin
      data = Codi::ProjectGenerator.new(@project).call

      updates = {
        full_description: data["full_description"].presence || @project.full_description,
        tech_stack: Array(data["tech_stack"]).map(&:to_s).map(&:strip).reject(&:empty?),
        team_roles: Array(data["team_roles"]).map(&:to_s).map(&:strip).reject(&:empty?),
        objectives: Array(data["objectives"]).map(&:to_s).map(&:strip).reject(&:empty?),
        timeline: Array(data["timeline"]).map(&:to_s).map(&:strip).reject(&:empty?)
      }

      # Si jamais tout est vide (ou fallback), on garde au moins ce qui existe déjà
      @project.update(updates)

      redirect_to @project, notice: "Projet généré avec Codi."
    rescue => e
      Rails.logger.error("[ProjectsController#create] Codi generation failed: #{e.class} #{e.message}")
      redirect_to @project, alert: "Le projet a été créé, mais la génération IA a échoué. Réessaie plus tard."
    end
  end

  def show
  end

  def destroy
  @project = Project.find(params[:id])
  @project.destroy
  redirect_to projects_path, notice: "Projet supprimé avec succès💥."
  end

  def publish
    @project.update!(status: :published)
    redirect_to projects_path, notice: "Projet publié avec succès 🎉."
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.require(:project).permit(
      :title,
      :category,
      :level,
      :duration,
      :max_team_members,
      :short_description,
      :full_description
    )
  end
end
