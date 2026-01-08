class WebPage < Document
  validates :url, uniqueness: true, allow_nil: true
end
