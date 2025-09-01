require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  setup do
    @document = Document.create!(title: "Test Document", content: "Test content for system test")
  end

  test "user can delete a document from index with confirmation" do
    visit documents_path

    # Verify document is present
    assert_text @document.title

    # Click delete and accept confirmation
    accept_confirm "Are you sure you want to delete this document?" do
      click_on "Delete", match: :first
    end

    # Document should be removed from the page
    assert_no_text @document.title
  end

  test "user can delete a document from show page with confirmation" do
    visit document_path(@document)

    # Verify we're on the show page
    assert_text @document.title

    # Click delete and accept confirmation
    accept_confirm "Are you sure you want to delete this document?" do
      click_on "Delete"
    end

    # Should redirect to index page
    assert_current_path documents_path

    # Document should not be in the list
    assert_no_text @document.title
  end

  test "user can cancel document deletion" do
    visit documents_path

    # Verify document is present
    assert_text @document.title

    # Click delete but dismiss confirmation
    dismiss_confirm "Are you sure you want to delete this document?" do
      click_on "Delete", match: :first
    end

    # Document should still be present
    assert_text @document.title
  end
end
