class ProjectsController < ApplicationController
  before_action :set_project, only: [ :show, :publish ]

  def index
    @projects = Project.status_published.order(created_at: :desc)
  end

  def new
    @project = Project.new(max_team_members: 5)
  end

  def create
    @project = Project.new(project_params)
    @project.status = :draft

    if @project.save
      data = Codi::ProjectGenerator.new(@project).call

      @project.update!(
        full_description: data["full_description"].presence || @project.full_description,
        tech_stack: Array(data["tech_stack"]),
        team_roles: Array(data["team_roles"]),
        objectives: Array(data["objectives"]),
        timeline: Array(data["timeline"])
      )

      redirect_to @project, notice: "Projet généré avec Codi."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def publish
    @project.update!(status: :published)
    redirect_to projects_path, notice: "Projet publié."
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
