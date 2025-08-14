module Resources
  class Builder
    extend Callable

    def call
      Dir.glob(Rails.root.join("docs", "resources", "*")).map do |file_path|
        next unless File.file?(file_path)

        file_name = File.basename(file_path)
        mime_type = case File.extname(file_name)
        when ".md" then "text/markdown"
        when ".txt" then "text/plain"
        when ".pdf" then "application/pdf"
        end
        description = File.open(file_path, &:gets)


        MCP::Resource.new(
          uri: "file:///#{file_name}",
          name: file_name,
          description:,
          mime_type: mime_type,
        )
      end.compact
    end
  end
end
