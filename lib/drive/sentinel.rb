# frozen_string_literal: true

require "securerandom"
require_relative "tmux"
require_relative "errors"

module Drive
  module Sentinel
    START_PREFIX = "__START_"
    DONE_PREFIX = "__DONE_"

    module_function

    def generate_token
      SecureRandom.hex(4)
    end

    def start_marker(token)
      "#{START_PREFIX}#{token}"
    end

    def done_marker(token)
      "#{DONE_PREFIX}#{token}"
    end

    def wrap_command(cmd, token)
      %Q(echo "#{start_marker(token)}" ; #{cmd} ; echo "#{done_marker(token)}:$?")
    end

    def detect_completion(captured, token)
      done_re = /^#{Regexp.escape(done_marker(token))}:(\d+)\s*$/
      done_match = captured.match(done_re)
      return [false, nil, ""] unless done_match

      exit_code = done_match[1].to_i
      start_re = /^#{Regexp.escape(start_marker(token))}\s*$/
      start_match = captured.match(start_re)

      output = if start_match
        captured[start_match.end(0)...done_match.begin(0)].strip
      else
        captured[0...done_match.begin(0)].strip
      end

      [true, exit_code, output]
    end

    def run_and_wait(session, cmd, pane: nil, timeout: 30.0, poll_interval: 0.2)
      token = generate_token
      wrapped = wrap_command(cmd, token)
      Tmux.send_keys(session, wrapped, pane: pane, enter: true, literal: false)

      deadline = timeout.zero? ? nil : Time.now + timeout
      loop do
        sleep poll_interval
        captured = Tmux.capture_pane(session, pane: pane, start_line: -500)
        found, exit_code, output = detect_completion(captured, token)
        return [exit_code, output] if found

        if deadline && Time.now >= deadline
          raise CommandTimeoutError.new(session: session, cmd: cmd, timeout: timeout)
        end
      end
    end
  end
end
