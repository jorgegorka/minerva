class Chat < ApplicationRecord
  include ProjectScoped

  acts_as_chat
end
