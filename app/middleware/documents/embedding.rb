module Documents
  class Embedding
    extend Callable

    DEFAULT_PROVIDER = "ollama" # "openai", "mistral", etc.

    def initialize(document)
      @document = document
    end

    def call
      text = [ document.title, document.content ].join("\n\n")
      vectors, dims = embed(text)

      document.update!(
        embedding: ::Pgvector::Vector.new(vectors),
        embedding_dimensions: dims,
        embedding_md5: document.current_md5,
        embedding_generated_at: Time.current
      )
    end

    private

      attr_reader :document

      def embed(text)
        result = RubyLLM.embed(text, model: "nomic-embed-text:v1.5", provider: DEFAULT_PROVIDER)
        vectors = result.vectors
        dims    = vectors.size
        Rails.logger.info("Generated embedding with #{dims} dimensions")

        [ vectors, dims ]
      end
  end
end
