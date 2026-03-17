module ProjectScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :project
    default_scope -> { Current.project ? where(project_id: Current.project.id) : all }
    before_validation { self.project_id ||= Current.project&.id }
  end
end
