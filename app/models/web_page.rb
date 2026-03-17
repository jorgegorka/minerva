class WebPage < Document
  validates :url, uniqueness: { scope: :project_id }, allow_nil: true
end
