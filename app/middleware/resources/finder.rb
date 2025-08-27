module Resources
  class Finder
    class << self
      def call
        new.call
      end
    end

    def call
      Document.all.map do |doc|
        create_resource(doc)
      end
    end

    private

    def create_resource(document)
      MCP::Resource.new(
        uri: "file://docs/#{document.id}",
        name: document.title,
        description: document.content,
        mime_type: "text/markdown"
      )
    end
  end
end
