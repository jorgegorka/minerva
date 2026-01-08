class CreateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find document_id
    return unless document.needs_embedding?

    Documents::Embedding.call(document)
  end
end
