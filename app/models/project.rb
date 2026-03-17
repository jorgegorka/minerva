class Project < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :documents, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :chats, dependent: :destroy
  has_many :messages, dependent: :destroy
  has_many :tool_calls, dependent: :destroy
end
