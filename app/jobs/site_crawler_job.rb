class SiteCrawlerJob < ApplicationJob
  queue_as :default

  def perform(site_id)
    site = Site.unscoped.find(site_id)
    WebPages::SiteCrawler.new(site.url, max_depth: site.max_depth, project_id: site.project_id).crawl
  end
end
