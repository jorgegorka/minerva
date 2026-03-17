# frozen_string_literal: true

require "json"
require_relative "errors"

module Drive
  module Output
    module_function

    def emit(data, json:, human_lines:)
      if json
        puts JSON.generate(data)
      elsif human_lines.is_a?(Array)
        human_lines.each { |line| puts line }
      else
        puts human_lines
      end
    end

    def emit_error(error, json:)
      if json
        puts JSON.generate(error.to_h)
      else
        $stderr.puts "Error: #{error.message}"
      end
      exit 1
    end
  end
end
