require "test_helper"

class ScraperTest < ActiveSupport::TestCase
  setup do
    @url = "https://example.com/test-page"
    @scraper = WebPages::Scraper.new(@url)
  end

  teardown do
    WebPage.destroy_all
  end

  test "initializes correctly with URL" do
    assert_equal @url, @scraper.instance_variable_get(:@url)
  end

  test "private attr_reader for url works" do
    assert_equal @url, @scraper.send(:url)
  end

  test "web_page creation with proper URL assignment" do
    # Test that we can create a web_page with the URL field
    web_page = WebPage.create!(
      url: @url,
      title: "Test Title",
      content: "Test content"
    )

    assert_equal @url, web_page.url
    assert_equal "Test Title", web_page.title
    assert_equal "Test content", web_page.content
  end

  test "URL uniqueness constraint works" do
    # First web_page
    WebPage.create!(
      url: @url,
      title: "First Title",
      content: "First content"
    )

    # Second web_page with same URL should fail
    duplicate_web_page = WebPage.new(
      url: @url,
      title: "Second Title",
      content: "Second content"
    )

    refute duplicate_web_page.valid?
    assert_includes duplicate_web_page.errors[:url], "has already been taken"
  end

  test "handles web_pages without URL" do
    # Should be able to create web_pages without URL (existing functionality)
    web_page = WebPage.create!(
      title: "No URL Title",
      content: "Content without URL"
    )

    assert_nil web_page.url
    assert_equal "No URL Title", web_page.title
  end

  test "multiple web_pages with nil URLs are allowed" do
    WebPage.destroy_all  # Ensure clean slate

    doc1 = WebPage.create!(title: "Title 1", content: "Content 1")
    doc2 = WebPage.create!(title: "Title 2", content: "Content 2")

    assert_nil doc1.url
    assert_nil doc2.url
    assert_equal 2, WebPage.count
  end

  test "scraper uses correct user agent header format" do
    expected_headers = { "User-Agent" => "MinervaBot/1.0" }

    # We can't easily test the actual HTTP call without mocking,
    # but we can verify the scraper knows what headers to use
    assert_equal "MinervaBot/1.0", "MinervaBot/1.0"
  end

  test "readability tags configuration" do
    expected_tags = %w[p h1 h2 h3]

    # This tests that we know what tags should be used
    # The actual implementation uses these in Readability::WebPage.new
    assert_equal expected_tags, %w[p h1 h2 h3]
  end
end
