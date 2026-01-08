require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  def setup
    @document = documents(:one)
  end

  test "enqueues PDF processing job when PDF is attached to new document" do
    document = Document.new(title: "Test PDF", content: "Processing...")
    document.file.attach(
      io: StringIO.new("%PDF-1.4 test"),
      filename: "test.pdf",
      content_type: "application/pdf"
    )

    # Should enqueue both PDF processing and embedding jobs
    assert_enqueued_jobs 1, only: ProcessPdfAttachmentJob do
      document.save!
    end

    assert_enqueued_with job: CreateEmbeddingJob, args: [ document.id ]
  end

  test "does not enqueue PDF processing for non-PDF files" do
    document = Document.new(title: "Test Text", content: "test")

    assert_no_enqueued_jobs(only: ProcessPdfAttachmentJob) do
      document.file.attach(
        io: StringIO.new("test content"),
        filename: "test.txt",
        content_type: "text/plain"
      )
      document.save!
    end
  end

  test "does not enqueue PDF processing when document already has content" do
    document = Document.new(title: "Test PDF", content: "existing content")

    # Should not enqueue PDF processing but may enqueue embedding job
    assert_no_enqueued_jobs(only: ProcessPdfAttachmentJob) do
      document.file.attach(
        io: StringIO.new("%PDF-1.4 test"),
        filename: "test.pdf",
        content_type: "application/pdf"
      )
      document.save!
    end
  end

  test "enqueues embedding job when content changes" do
    assert_enqueued_jobs 1, only: CreateEmbeddingJob do
      @document.update!(content: "new content")
    end
  end
end
