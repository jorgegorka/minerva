class Category < ApplicationRecord
  include ProjectScoped

  has_many :documents, dependent: :destroy

  validates :title, presence: true
end
