module Tools
  class DocumentSearch < MCP::Tool
    description "Searches knowledge base for relevant information"
    input_schema(
      {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "User query"
          }
        },
        required: [ "query" ]
      }
    )

    class << self
      def call(**parameters)
        query = parameters[:query]
        embedding = RubyLLM.embed(query, model: "nomic-embed-text:v1.5", provider: "ollama").vectors
        documents = Document.nearest_neighbors(:embedding, embedding, distance: "euclidean").limit(3)
        documents.map { |doc|
          "#{doc.title}: #{doc.content}"
        }.join("\n\n---\n\n")
      end
    end
  end
end
