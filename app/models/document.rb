class Document < ApplicationRecord
  has_neighbors :embedding

  validates :title, presence: true

  has_one_attached :file

  after_initialize :initialize_file_tracking
  after_find :initialize_file_tracking

  after_commit :enqueue_pdf_processing, on: [ :create, :update ], if: :file_attachment_changed?

  after_update :enqueue_embedding_job, if: :needs_embedding?

  scope :search, ->(query) {
    where("to_tsvector(content) @@ plainto_tsquery(?)", query)
      .order(Arel.sql("ts_rank_cd(to_tsvector(content), plainto_tsquery(?)) DESC", query))
  }

  def current_md5
    Digest::MD5.hexdigest([ title, content ].join("\n\n"))
  end

  def needs_embedding?
    content.present? && (embedding.blank? || embedding_md5 != current_md5)
  end

  private

    def enqueue_embedding_job
      CreateEmbeddingJob.perform_later(id)
    end

    def enqueue_pdf_processing
      return unless file.attached? && file.content_type == "application/pdf"

      Rails.logger.info "Document #{id}: Enqueuing PDF processing job for file change"
      ProcessPdfAttachmentJob.perform_later(id)
    end

    def initialize_file_tracking
      if persisted? && file.attached?
        @previous_filename = file.filename.to_s
        @previous_file_size = file.byte_size
      else
        @previous_filename = nil
        @previous_file_size = nil
      end
    end

    def file_attachment_changed?
      return file.attached? if new_record?

      return false unless file.attached?

      return true if @previous_filename.nil? && @previous_file_size.nil?

      current_filename = file.filename.to_s
      current_file_size = file.byte_size

      filename_changed = (current_filename != @previous_filename)
      size_changed = (current_file_size != @previous_file_size)

      filename_changed || size_changed
    end
end
