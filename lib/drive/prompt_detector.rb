# frozen_string_literal: true

module Drive
  module PromptDetector
    WAITING_PATTERNS = [
      /\[y\/n\]/i,
      /\[yes\/no\]/i,
      /password\s*:/i,
      /are you sure/i,
      /press enter/i,
      /enter to continue/i,
      /continue\?\s*\[/i,
      /confirm/i,
      /\(y\/n\)/i,
      /overwrite\?/i
    ].freeze

    ERROR_PATTERNS = [
      /^Error:/i,
      /^fatal:/i,
      /not found/i,
      /Traceback \(most recent/,
      /^FAILED/,
      /permission denied/i,
      /cannot /i,
      /No such file/i,
      /command not found/i,
      /segmentation fault/i
    ].freeze

    PROMPT_PATTERNS = [
      /[\$#%>]\s*$/,
      /^irb\(\w+\):\d+:\d+[>*]\s*$/,
      /^pry\(\w+\)>\s*$/,
      /^>>>\s*$/,
      /^In \[\d+\]:\s*$/
    ].freeze

    module_function

    def detect(output)
      return :unknown if output.nil? || output.strip.empty?

      lines = output.strip.lines.last(5).map(&:strip)

      return :waiting_for_input if lines.any? { |line| WAITING_PATTERNS.any? { |pat| pat.match?(line) } }
      return :error if lines.any? { |line| ERROR_PATTERNS.any? { |pat| pat.match?(line) } }
      return :idle if lines.any? { |line| PROMPT_PATTERNS.any? { |pat| pat.match?(line) } }

      :active
    end

    def status_label(state)
      case state
      when :active then "Running"
      when :waiting_for_input then "Waiting"
      when :idle then "Idle"
      when :error then "Error"
      when :unknown then "Unknown"
      else state.to_s.capitalize
      end
    end

    def status_css_class(state)
      case state
      when :active then "console-status--active"
      when :waiting_for_input then "console-status--waiting"
      when :idle then "console-status--idle"
      when :error then "console-status--error"
      else "console-status--unknown"
      end
    end
  end
end
