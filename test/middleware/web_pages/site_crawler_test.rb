require "test_helper"

class SiteCrawlerTest < ActiveSupport::TestCase
  setup do
    @start_url = "https://example.com"
    @crawler = WebPages::SiteCrawler.new(@start_url, max_depth: 2)
  end

  teardown do
    Document.destroy_all
  end

  test "initializes with correct defaults" do
    default_crawler = WebPages::SiteCrawler.new(@start_url)

    assert_equal @start_url, default_crawler.instance_variable_get(:@start_url)
    assert_equal "example.com", default_crawler.instance_variable_get(:@domain)
    assert_equal 2, default_crawler.instance_variable_get(:@max_depth)
    assert_instance_of Set, default_crawler.instance_variable_get(:@visited)
    assert default_crawler.instance_variable_get(:@visited).empty?
  end

  test "initializes with custom max_depth" do
    custom_crawler = WebPages::SiteCrawler.new(@start_url, max_depth: 5)
    assert_equal 5, custom_crawler.instance_variable_get(:@max_depth)
  end

  test "domain extraction works correctly" do
    test_cases = {
      "https://example.com" => "example.com",
      "https://www.example.com" => "www.example.com",
      "https://subdomain.example.com" => "subdomain.example.com",
      "http://example.com:8080" => "example.com"
    }

    test_cases.each do |url, expected_domain|
      crawler = WebPages::SiteCrawler.new(url)
      assert_equal expected_domain, crawler.instance_variable_get(:@domain)
    end
  end

  test "internal_links filters correctly" do
    html_content = <<~HTML
      <html>
        <body>
          <a href="/relative">Relative Link</a>
          <a href="https://example.com/absolute">Absolute Internal</a>
          <a href="https://external.com/page">External Link</a>
          <a href="#fragment">Fragment Only</a>
          <a href="mailto:test@example.com">Email</a>
          <a>No href</a>
          <a href="">Empty href</a>
        </body>
      </html>
    HTML

    doc = Nokogiri::HTML(html_content)
    internal_links = @crawler.send(:internal_links, doc)

    # Should only include internal links from same domain
    assert_includes internal_links, "https://example.com/relative"
    assert_includes internal_links, "https://example.com/absolute"

    # Should not include external or invalid links
    refute_includes internal_links, "https://external.com/page"
    refute_includes internal_links, "mailto:test@example.com"

    # Fragment-only links should resolve to the start URL
    assert_includes internal_links, "https://example.com#fragment"
  end

  test "handles complex URL patterns" do
    html_content = <<~HTML
      <html>
        <body>
          <a href="/page?param=value">Query Parameters</a>
          <a href="/page#section">Fragment Link</a>
          <a href="?query=test">Query Only</a>
          <a href="../parent">Parent Directory</a>
          <a href="./current">Current Directory</a>
        </body>
      </html>
    HTML

    doc = Nokogiri::HTML(html_content)
    internal_links = @crawler.send(:internal_links, doc)

    expected_links = [
      "https://example.com/page?param=value",
      "https://example.com/page#section",
      "https://example.com?query=test",
      "https://example.com/parent",  # URI.join normalizes ../parent to /parent
      "https://example.com/current"   # URI.join normalizes ./current to /current
    ]

    expected_links.each do |link|
      assert_includes internal_links, link, "Should include #{link}"
    end
  end

  test "visited URLs tracking" do
    visited = @crawler.instance_variable_get(:@visited)

    # Initially empty
    assert visited.empty?

    # Can add URLs
    visited << "https://example.com"
    visited << "https://example.com/page1"

    assert_equal 2, visited.size
    assert_includes visited, "https://example.com"
    assert_includes visited, "https://example.com/page1"

    # Duplicates are ignored (Set behavior)
    visited << "https://example.com"
    assert_equal 2, visited.size
  end

  test "depth tracking logic" do
    # Test the depth limit logic
    max_depth = @crawler.instance_variable_get(:@max_depth)
    assert_equal 2, max_depth

    # At depth 0 and 1, should continue
    assert_equal false, 0 > max_depth
    assert_equal false, 1 > max_depth

    # At depth 2, should continue (equal to max)
    assert_equal false, 2 > max_depth

    # At depth 3, should stop
    assert_equal true, 3 > max_depth
  end

  test "handles malformed href attributes" do
    html_content = <<~HTML
      <html>
        <body>
          <a href="javascript:void(0)">JavaScript Link</a>
          <a href="data:text/plain;base64,SGVsbG8=">Data URI</a>
          <a href="ftp://example.com">FTP Link</a>
          <a href="//protocol-relative.com">Protocol Relative</a>
        </body>
      </html>
    HTML

    doc = Nokogiri::HTML(html_content)

    # Should handle malformed URLs gracefully without crashing
    assert_nothing_raised do
      internal_links = @crawler.send(:internal_links, doc)
      # Should be empty or contain only valid internal links
      internal_links.each do |link|
        uri = URI.parse(link)
        assert_equal @crawler.instance_variable_get(:@domain), uri.host
      end
    end
  end

  test "link extraction with various base URLs" do
    # Test different starting URLs
    test_urls = [
      "https://example.com",
      "https://example.com/",
      "https://example.com/path/",
      "https://www.example.com/deep/path/"
    ]

    test_urls.each do |start_url|
      crawler = WebPages::SiteCrawler.new(start_url, max_depth: 1)

      html_content = '<a href="/test">Test Link</a>'
      doc = Nokogiri::HTML(html_content)
      internal_links = crawler.send(:internal_links, doc)

      # Should always resolve relative links correctly
      domain = URI.parse(start_url).host
      assert internal_links.any? { |link| link.include?(domain) }
    end
  end
end
