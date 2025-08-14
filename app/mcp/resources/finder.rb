  module Resources
    class Finder
      extend Callable

      def initialize(uri)
        @uri = uri
      end

      def call
        Rails.logger.info "MCP::Resources::Finder called with URI: #{uri}"
        @requested_file = uri.sub(/^file:\/\/\//, "")

        [ {
          uri:,
          mimeType: "text/markdown",
          text: find_file_content
        } ]
      end

      private

      attr_reader :uri, :requested_file

      def find_file_content
        # Convert the URI to a file path
        file_path = File.join(Rails.root, "docs", "resources", requested_file)
        # Check if the file exists
        if File.exist?(file_path)
          # Read the file content
          File.read(file_path)
        else
          "File not found: #{file_path}"
        end
      end
    end
  end
