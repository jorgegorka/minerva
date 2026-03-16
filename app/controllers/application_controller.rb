class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :set_current_project

  private

  def current_user
    # TODO: Implement proper user authentication
    @current_user ||= Struct.new(:id).new(1)
  end

  def set_current_project
    project = if session[:project_id]
      Project.unscoped.find_by(id: session[:project_id])
    end

    project ||= Project.unscoped.order(:created_at).first

    if project
      session[:project_id] = project.id
      Current.project = project
    else
      redirect_to new_project_path
    end
  end
end
