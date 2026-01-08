require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category = categories(:development)
  end

  test "should get index" do
    get categories_url
    assert_response :success
    assert_select "h1", /Categories/
  end

  test "should get new" do
    get new_category_url
    assert_response :success
  end

  test "should create category" do
    assert_difference("Category.count") do
      post categories_url, params: {
        category: {
          title: "New Category"
        }
      }
    end

    assert_redirected_to categories_url
    follow_redirect!
    assert_select ".alert", /successfully created/i
  end

  test "should not create category without title" do
    assert_no_difference("Category.count") do
      post categories_url, params: {
        category: {
          title: ""
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_category_url(@category)
    assert_response :success
  end

  test "should update category" do
    patch category_url(@category), params: {
      category: {
        title: "Updated Category Title"
      }
    }

    assert_redirected_to categories_url
    @category.reload
    assert_equal "Updated Category Title", @category.title
  end

  test "should not update category with blank title" do
    patch category_url(@category), params: {
      category: {
        title: ""
      }
    }

    assert_response :unprocessable_entity
    @category.reload
    assert_equal "Development", @category.title
  end

  test "should destroy category" do
    category = Category.create!(title: "Temporary Category")

    assert_difference("Category.count", -1) do
      delete category_url(category)
    end

    assert_redirected_to categories_url
  end

  test "should destroy category with turbo stream from index" do
    category = Category.create!(title: "Temporary Category")

    assert_difference("Category.count", -1) do
      delete category_url(category), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
  end

  test "destroying category destroys associated documents" do
    category = Category.create!(title: "Category With Documents")
    text = Text.create!(title: "Text in Category", content: "Content", category: category)

    assert_difference("Category.count", -1) do
      assert_difference("Document.count", -1) do
        delete category_url(category)
      end
    end
  end
end
