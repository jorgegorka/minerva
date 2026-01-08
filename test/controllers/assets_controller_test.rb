require "test_helper"

class AssetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @asset = documents(:asset_one)
    @category = categories(:development)
  end

  test "should get index" do
    get assets_url
    assert_response :success
    assert_select "h1", /Assets/
  end

  test "should get new" do
    get new_asset_url
    assert_response :success
  end

  test "should create asset with file" do
    file = fixture_file_upload("sample.pdf", "application/pdf")

    assert_difference("Asset.count") do
      post assets_url, params: {
        asset: {
          title: "New Asset",
          file: file,
          category_id: @category.id
        }
      }
    end

    assert_redirected_to asset_url(Asset.last)
    follow_redirect!
    assert_select ".alert", /successfully created/i
  end

  test "should not create asset without file" do
    assert_no_difference("Asset.count") do
      post assets_url, params: {
        asset: {
          title: "Asset Without File",
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create asset without title" do
    file = fixture_file_upload("sample.pdf", "application/pdf")

    assert_no_difference("Asset.count") do
      post assets_url, params: {
        asset: {
          title: "",
          file: file,
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show asset" do
    get asset_url(@asset)
    assert_response :success
  end

  test "should get edit" do
    get edit_asset_url(@asset)
    assert_response :success
  end

  test "should update asset with new file" do
    file = fixture_file_upload("sample.pdf", "application/pdf")

    patch asset_url(@asset), params: {
      asset: {
        title: "Updated Asset Title",
        file: file,
        category_id: @category.id
      }
    }

    assert_redirected_to asset_url(@asset)
    @asset.reload
    assert_equal "Updated Asset Title", @asset.title
  end

  test "should destroy asset" do
    assert_difference("Asset.count", -1) do
      delete asset_url(@asset)
    end

    assert_redirected_to assets_url
  end

  test "should destroy asset with turbo stream from index" do
    assert_difference("Asset.count", -1) do
      delete asset_url(@asset), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end
end
