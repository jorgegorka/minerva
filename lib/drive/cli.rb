# frozen_string_literal: true

require "thor"
require_relative "errors"
require_relative "output"
require_relative "tmux"
require_relative "sentinel"

module Drive
  class Session < Thor
    namespace :session

    desc "create NAME", "Create a new tmux session"
    option :window, type: :string, desc: "Name for the initial window"
    option :dir, type: :string, desc: "Working directory"
    option :detach, type: :boolean, default: false, desc: "Create headless (no Terminal window)"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def create(name)
      Tmux.create_session(name, window_name: options[:window], start_directory: options[:dir], detach: options[:detach])
      Output.emit(
        { ok: true, action: "create", session: name, detach: options[:detach] },
        json: options[:json],
        human_lines: "Created session: #{name}#{options[:detach] ? ' (detached)' : ''}"
      )
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "list", "List all tmux sessions"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def list
      sessions = Tmux.list_sessions
      if options[:json]
        Output.emit({ ok: true, sessions: sessions.map(&:to_h) }, json: true, human_lines: "")
      else
        if sessions.empty?
          puts "No tmux sessions."
        else
          sessions.each do |s|
            attached = s.attached ? " (attached)" : ""
            puts "  #{s.name.ljust(20)} #{s.windows} window(s)  #{s.created}#{attached}"
          end
        end
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "kill NAME", "Kill a tmux session"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def kill(name)
      Tmux.kill_session(name)
      Output.emit(
        { ok: true, action: "kill", session: name },
        json: options[:json],
        human_lines: "Killed session: #{name}"
      )
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end
  end

  class Cli < Thor
    desc "session SUBCOMMAND", "Manage tmux sessions"
    subcommand "session", Session

    map "run" => :run_command, "send" => :send_command
    desc "run SESSION CMD", "Run a command and wait for completion"
    option :timeout, type: :numeric, default: 30, desc: "Max seconds to wait (0 = no limit)"
    option :pane, type: :string, desc: "Target pane index"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def run_command(session, cmd)
      exit_code, output = Sentinel.run_and_wait(
        session, cmd, pane: options[:pane], timeout: options[:timeout].to_f
      )
      data = { ok: exit_code == 0, session: session, command: cmd, exit_code: exit_code, output: output }
      human = exit_code == 0 ? output : "[exit #{exit_code}]\n#{output}"
      Output.emit(data, json: options[:json], human_lines: human)
      exit(exit_code) unless exit_code == 0
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "send SESSION TEXT", "Send raw keystrokes to a session"
    option :pane, type: :string, desc: "Target pane index"
    option :enter, type: :boolean, default: true, desc: "Append Enter key"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def send_command(session, text)
      Tmux.send_keys(session, text, pane: options[:pane], enter: options[:enter], literal: true)
      Output.emit(
        { ok: true, action: "send", session: session, text: text, enter: options[:enter] },
        json: options[:json],
        human_lines: "Sent to #{session}: #{text}#{options[:enter] ? ' [Enter]' : ''}"
      )
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "logs SESSION", "Capture pane output"
    option :pane, type: :string, desc: "Target pane index"
    option :lines, type: :numeric, desc: "Scrollback lines to capture"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def logs(session)
      start_line = options[:lines] ? -options[:lines].abs : nil
      content = Tmux.capture_pane(session, pane: options[:pane], start_line: start_line)
      Output.emit(
        { ok: true, session: session, content: content },
        json: options[:json],
        human_lines: content
      )
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "poll SESSION", "Wait for pane output to match a pattern"
    option :until, type: :string, required: true, desc: "Regex pattern to match"
    option :timeout, type: :numeric, default: 30, desc: "Max seconds to wait"
    option :interval, type: :numeric, default: 0.5, desc: "Seconds between polls"
    option :pane, type: :string, desc: "Target pane index"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def poll(session)
      pattern = options[:until]
      begin
        compiled = Regexp.new(pattern)
      rescue RegexpError => e
        $stderr.puts "Error: Invalid regex: #{e.message}"
        exit 1
      end

      timeout = options[:timeout].to_f
      interval = options[:interval].to_f
      deadline = Time.now + timeout

      loop do
        content = Tmux.capture_pane(session, pane: options[:pane], start_line: -200)
        match = compiled.match(content)
        if match
          Output.emit(
            { ok: true, session: session, pattern: pattern, match: match[0], content: content },
            json: options[:json],
            human_lines: ["Pattern matched: #{match[0]}", content]
          )
          return
        end

        if Time.now >= deadline
          raise PatternNotFoundError.new(pattern: pattern, session: session, timeout: timeout)
        end
        sleep interval
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "fanout CMD", "Run command in parallel across sessions"
    option :targets, type: :string, required: true, desc: "Comma-separated session names"
    option :timeout, type: :numeric, default: 30, desc: "Max seconds per session"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def fanout(cmd)
      session_names = options[:targets].split(",").map(&:strip).reject(&:empty?)
      if session_names.empty?
        $stderr.puts "Error: No targets specified."
        exit 1
      end

      timeout = options[:timeout].to_f
      threads = session_names.map do |name|
        Thread.new(name) do |session_name|
          begin
            exit_code, output = Sentinel.run_and_wait(session_name, cmd, timeout: timeout)
            { session: session_name, ok: exit_code == 0, exit_code: exit_code, output: output }
          rescue DriveError => e
            { session: session_name, ok: false, error: e.code, message: e.message }
          end
        end
      end

      results = threads.map(&:value)
      order = session_names.each_with_index.to_h
      results.sort_by! { |r| order[r[:session]] || 999 }
      all_ok = results.all? { |r| r[:ok] }

      if options[:json]
        Output.emit({ ok: all_ok, command: cmd, results: results }, json: true, human_lines: "")
      else
        results.each do |r|
          status = r[:ok] ? "ok" : "FAIL"
          puts "--- #{r[:session]} [#{status}] ---"
          puts r[:output] if r[:output]
          puts "  Error: #{r[:message]}" if r[:message]
          puts
        end
      end

      exit 1 unless all_ok
    end
  end
end
