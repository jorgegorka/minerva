require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @document = Document.create!(title: "Test Document", content: "Test content")
  end

  test "should get index" do
    get documents_url
    assert_response :success
    assert_includes response.body, "Documents"
  end

  test "should get new" do
    get new_document_url
    assert_response :success
    assert_includes response.body, "New Document"
  end

  test "should create document" do
    assert_difference("Document.count") do
      post documents_url, params: { document: { title: "New Document", content: "New content" } }
    end
    assert_redirected_to document_url(Document.last)
  end

  test "should show document" do
    get document_url(@document)
    assert_response :success
    assert_includes response.body, @document.title
  end

  test "should get edit" do
    get edit_document_url(@document)
    assert_response :success
    assert_includes response.body, "Edit Document"
  end

  test "should update document" do
    patch document_url(@document), params: { document: { title: "Updated Title", content: "Updated content" } }
    assert_redirected_to document_url(@document)
    @document.reload
    assert_equal "Updated Title", @document.title
  end

  test "should destroy document" do
    assert_difference("Document.count", -1) do
      delete document_url(@document)
    end
    assert_redirected_to documents_url
  end
end
