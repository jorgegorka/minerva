class ToolCall < ApplicationRecord
  include ProjectScoped

  acts_as_tool_call

  before_validation { self.project_id = message.project_id if project_id.blank? && message }
end
