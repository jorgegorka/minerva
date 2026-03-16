class ProjectsController < ApplicationController
  skip_before_action :set_current_project, only: [:new, :create]

  def index
    @projects = Project.unscoped.order(:name)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)

    if @project.save
      session[:project_id] = @project.id
      Current.project = @project
      redirect_to root_url, notice: "Project was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def switch
    project = Project.unscoped.find(params[:id])
    session[:project_id] = project.id
    Current.project = project
    redirect_to root_url, notice: "Switched to #{project.name}."
  end

  private

  def project_params
    params.require(:project).permit(:name)
  end
end
