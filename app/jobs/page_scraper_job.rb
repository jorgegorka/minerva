class PageScraperJob < ApplicationJob
  queue_as :default

  def perform(url, project_id)
    WebPages::Scraper.new(url, project_id: project_id).scrape
  end
end
