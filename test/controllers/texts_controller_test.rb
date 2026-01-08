require "test_helper"

class TextsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @text = documents(:text_one)
    @category = categories(:development)
  end

  test "should get index" do
    get texts_url
    assert_response :success
    assert_select "h1", /Texts/
  end

  test "should get new" do
    get new_text_url
    assert_response :success
  end

  test "should create text" do
    assert_difference("Text.count") do
      post texts_url, params: {
        text: {
          title: "New Text",
          content: "This is new text content",
          category_id: @category.id
        }
      }
    end

    assert_redirected_to text_url(Text.last)
    follow_redirect!
    assert_select ".alert", /successfully created/i
  end

  test "should not create text without title" do
    assert_no_difference("Text.count") do
      post texts_url, params: {
        text: {
          title: "",
          content: "Some content",
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should not create text without content" do
    assert_no_difference("Text.count") do
      post texts_url, params: {
        text: {
          title: "Title Without Content",
          content: "",
          category_id: @category.id
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should show text" do
    get text_url(@text)
    assert_response :success
  end

  test "should get edit" do
    get edit_text_url(@text)
    assert_response :success
  end

  test "should update text" do
    patch text_url(@text), params: {
      text: {
        title: "Updated Text Title",
        content: "Updated content",
        category_id: @category.id
      }
    }

    assert_redirected_to text_url(@text)
    @text.reload
    assert_equal "Updated Text Title", @text.title
    assert_equal "Updated content", @text.content
  end

  test "should destroy text" do
    assert_difference("Text.count", -1) do
      delete text_url(@text)
    end

    assert_redirected_to texts_url
  end

  test "should destroy text with turbo stream from index" do
    assert_difference("Text.count", -1) do
      delete text_url(@text), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end
end
