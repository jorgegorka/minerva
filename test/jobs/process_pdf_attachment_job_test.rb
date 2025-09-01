require "test_helper"

class ProcessPdfAttachmentJobTest < ActiveSupport::TestCase
  def setup
    @document = documents(:one)
  end

  test "job skips non-PDF files" do
    @document.file.attach(
      io: StringIO.new("test content"),
      filename: "test.txt",
      content_type: "text/plain"
    )

    original_content = @document.content

    ProcessPdfAttachmentJob.perform_now(@document.id)

    @document.reload
    assert_equal original_content, @document.content
  end

  test "job skips documents without attachments" do
    original_content = @document.content

    ProcessPdfAttachmentJob.perform_now(@document.id)

    @document.reload
    assert_equal original_content, @document.content
  end

  test "job initializes and can be called" do
    # Just verify the job can be instantiated and called without errors
    # when there's no file attached (should exit early)
    assert_nothing_raised do
      job = ProcessPdfAttachmentJob.new
      job.perform(@document.id)
    end
  end

  test "job handles PDF files correctly (integration test)" do
    skip "This test requires actual docling command - run manually to test full integration"

    # If you want to test with a real PDF file:
    # @document.update!(content: "Processing...")
    # @document.file.attach(
    #   io: File.open("path/to/test.pdf"),
    #   filename: "test.pdf",
    #   content_type: "application/pdf"
    # )
    # ProcessPdfAttachmentJob.perform_now(@document.id)
    # @document.reload
    # assert_not_equal "Processing...", @document.content
  end
end
