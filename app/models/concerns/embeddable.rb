module Embeddable
  extend ActiveSupport::Concern

  included do
    has_neighbors :embedding

    after_commit :enqueue_embedding_job, on: [ :create, :update ], if: :needs_embedding?
  end

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
end
