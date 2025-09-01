class WebPage < Document
  validates :url, uniqueness: true, allow_blank: true
end
