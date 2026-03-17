class Message < ApplicationRecord
  include ProjectScoped

  acts_as_message

  before_validation { self.project_id = chat.project_id if project_id.blank? && chat }
end
