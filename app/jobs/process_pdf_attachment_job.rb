require "open3"

class ProcessPdfAttachmentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)

    unless document.file.attached?
      Rails.logger.info "ProcessPdfAttachmentJob: No file attached to document #{document_id}"
      return
    end

    unless document.file.content_type == "application/pdf"
      Rails.logger.info "ProcessPdfAttachmentJob: File is not a PDF for document #{document_id} (#{document.file.content_type})"
      return
    end

    Rails.logger.info "ProcessPdfAttachmentJob: Processing PDF attachment for document #{document_id}"

    # Create temporary directory for processing
    Dir.mktmpdir("docling_") do |temp_dir|
      # Download PDF to temporary file
      pdf_path = File.join(temp_dir, "document.pdf")
      File.open(pdf_path, "wb") do |file|
        document.file.download { |chunk| file.write(chunk) }
      end

      # Run docling to convert PDF to markdown
      output_dir = temp_dir

      Rails.logger.info "ProcessPdfAttachmentJob: Running docling command on #{pdf_path}"

      # Use Open3 to safely execute command without shell interpolation
      stdout, stderr, status = Open3.capture3(
        "docling", pdf_path, "--output", output_dir, "--to", "md"
      )

      unless status.success?
        Rails.logger.error "ProcessPdfAttachmentJob: docling command failed for document #{document_id}"
        Rails.logger.error "ProcessPdfAttachmentJob: docling error output: #{stderr}"
        return
      end

      # Find generated markdown file (docling may name it differently)
      markdown_files = Dir[File.join(temp_dir, "document.md")]

      if markdown_files.empty?
        Rails.logger.error "ProcessPdfAttachmentJob: No markdown files generated in #{temp_dir}"
        Rails.logger.error "ProcessPdfAttachmentJob: Available files: #{Dir[File.join(temp_dir, '*')].join(', ')}"
        return
      end

      # Use the first (and likely only) markdown file
      markdown_path = markdown_files.first
      markdown_content = File.read(markdown_path)

      if markdown_content.strip.empty?
        Rails.logger.warn "ProcessPdfAttachmentJob: Generated markdown file is empty for document #{document_id}"
        return
      end

      Rails.logger.info "ProcessPdfAttachmentJob: Successfully extracted #{markdown_content.length} characters from PDF"

      # Update document content
      document.update!(content: markdown_content)
      Rails.logger.info "ProcessPdfAttachmentJob: Successfully updated document #{document_id} with PDF content"
    end

  rescue => e
    Rails.logger.error "ProcessPdfAttachmentJob: Error processing document #{document_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end
