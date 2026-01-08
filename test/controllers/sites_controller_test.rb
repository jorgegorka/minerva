require "test_helper"

class SitesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @site = documents(:site_one)
    @category = categories(:development)
  end

  test "should get index" do
    get sites_url
    assert_response :success
    assert_select "h1", /Sites/
  end

  test "should get new" do
    get new_site_url
    assert_response :success
  end

  test "should create site" do
    assert_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "New Site",
          url: "https://newsite.example.com",
          max_depth: 2,
          category_id: @category.id
        }
      }
    end

    assert_redirected_to site_url(Site.last)
    follow_redirect!
    assert_select ".alert", /successfully created/i
  end

  test "should not create site without title" do
    assert_no_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "",
          url: "https://example.com",
          max_depth: 2,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create site with invalid url" do
    assert_no_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "Invalid URL Site",
          url: "not-a-valid-url",
          max_depth: 2,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create site with duplicate url" do
    assert_no_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "Duplicate URL Site",
          url: @site.url,
          max_depth: 2,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create site without max_depth" do
    assert_no_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "No Max Depth Site",
          url: "https://no-depth.example.com",
          max_depth: nil,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create site with invalid max_depth" do
    assert_no_difference("Site.count") do
      post sites_url, params: {
        site: {
          title: "Invalid Max Depth Site",
          url: "https://invalid-depth.example.com",
          max_depth: 0,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show site" do
    get site_url(@site)
    assert_response :success
  end

  test "should get edit" do
    get edit_site_url(@site)
    assert_response :success
  end

  test "should update site" do
    patch site_url(@site), params: {
      site: {
        title: "Updated Site Title",
        url: "https://updated.example.com",
        max_depth: 5,
        category_id: @category.id
      }
    }

    assert_redirected_to site_url(@site)
    @site.reload
    assert_equal "Updated Site Title", @site.title
    assert_equal "https://updated.example.com", @site.url
    assert_equal 5, @site.max_depth
  end

  test "should destroy site" do
    assert_difference("Site.count", -1) do
      delete site_url(@site)
    end

    assert_redirected_to sites_url
  end

  test "should destroy site with turbo stream from index" do
    assert_difference("Site.count", -1) do
      delete site_url(@site), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end
end
