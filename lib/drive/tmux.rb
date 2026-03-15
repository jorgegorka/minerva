# frozen_string_literal: true

require "open3"
require "shellwords"
require_relative "errors"

module Drive
  module Tmux
    TMUX_TIMEOUT = 10

    SessionInfo = Data.define(:name, :windows, :created, :attached)
    RunResult = Data.define(:stdout, :stderr, :status)

    module_function

    def require_tmux
      path = `which tmux 2>/dev/null`.strip
      raise TmuxNotFoundError if path.empty?
      path
    end

    def run(args, check: true)
      tmux = require_tmux
      cmd = [tmux] + args

      stdout, stderr, pid_thread = nil
      Open3.popen3(*cmd) do |_stdin, out, err, wait_thr|
        pid = wait_thr.pid
        deadline = Time.now + TMUX_TIMEOUT

        stdout_reader = Thread.new { out.read }
        stderr_reader = Thread.new { err.read }

        remaining = deadline - Time.now
        if remaining > 0
          stdout = stdout_reader.join(remaining)&.value
          stderr = stderr_reader.join([deadline - Time.now, 0].max)&.value
        end

        unless wait_thr.join([deadline - Time.now, 0].max)
          Process.kill("KILL", pid) rescue nil
          raise TmuxCommandError.new(args: args, stderr: "tmux command timed out after #{TMUX_TIMEOUT}s")
        end

        pid_thread = wait_thr

        stdout ||= ""
        stderr ||= ""
      end

      status = pid_thread.value
      if check && !status.success?
        raise TmuxCommandError.new(args: args, stderr: (stderr || "").strip)
      end

      RunResult.new(stdout: stdout || "", stderr: stderr || "", status: status)
    rescue Errno::ENOENT
      raise TmuxNotFoundError
    end

    def session_exists?(name)
      result = run(["has-session", "-t", name], check: false)
      result.status.success?
    end

    def require_session(name)
      raise SessionNotFoundError.new(name) unless session_exists?(name)
    end

    def create_session(name, window_name: nil, start_directory: nil, detach: false)
      raise SessionExistsError.new(name) if session_exists?(name)

      if detach || !macos?
        args = ["new-session", "-d", "-s", name]
        args.push("-n", window_name) if window_name
        args.push("-c", start_directory) if start_directory
        run(args)
      else
        tmux_cmd = "tmux new-session -A -s #{Shellwords.escape(name)}"
        tmux_cmd += " -n #{Shellwords.escape(window_name)}" if window_name
        tmux_cmd += " -c #{Shellwords.escape(start_directory)}" if start_directory
        open_terminal_window(tmux_cmd)
        wait_for_session(name, timeout: 5.0)
      end
    end

    def list_sessions
      result = run(
        ["list-sessions", "-F", '#{session_name}|||#{session_windows}|||#{session_created_string}|||#{session_attached}'],
        check: false
      )
      return [] unless result.status.success?

      result.stdout.strip.split("\n").filter_map do |line|
        parts = line.split("|||")
        next unless parts.length >= 4
        SessionInfo.new(
          name: parts[0],
          windows: parts[1].to_i,
          created: parts[2],
          attached: parts[3] != "0"
        )
      end
    end

    def kill_session(name)
      require_session(name)
      run(["kill-session", "-t", name])
    end

    def resolve_target(session, pane = nil)
      pane ? "#{session}:.#{pane}" : "#{session}:"
    end

    def send_keys(session, keys, pane: nil, enter: true, literal: false)
      require_session(session)
      target = resolve_target(session, pane)
      args = ["send-keys", "-t", target]
      args << "-l" if literal
      args << keys
      run(args)
      run(["send-keys", "-t", target, "Enter"]) if enter
    end

    def capture_pane(session, pane: nil, start_line: nil, end_line: nil)
      require_session(session)
      target = resolve_target(session, pane)
      args = ["capture-pane", "-p", "-t", target]
      args.push("-S", start_line.to_s) if start_line
      args.push("-E", end_line.to_s) if end_line
      result = run(args)
      result.stdout.rstrip
    end

    # Private helpers

    def macos?
      RUBY_PLATFORM.include?("darwin")
    end

    def open_terminal_window(command)
      cwd = Dir.pwd
      shell_command = "cd '#{cwd}' && #{command}"
      escaped = shell_command.gsub("\\", "\\\\\\\\").gsub('"', '\\"')
      system("osascript", "-e", %Q(tell application "Terminal" to do script "#{escaped}"))
    rescue StandardError
      nil
    end

    def wait_for_session(name, timeout: 5.0)
      deadline = Time.now + timeout
      loop do
        return if session_exists?(name)
        if Time.now >= deadline
          raise TmuxCommandError.new(
            args: ["new-session", "-s", name],
            stderr: "Session '#{name}' did not appear within #{timeout}s"
          )
        end
        sleep 0.2
      end
    end

    private_class_method :macos?, :open_terminal_window, :wait_for_session
  end
end
