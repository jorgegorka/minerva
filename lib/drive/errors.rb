# frozen_string_literal: true

module Drive
  class DriveError < StandardError
    def code
      "error"
    end

    def to_h
      { ok: false, error: code, message: message }
    end
  end

  class TmuxNotFoundError < DriveError
    def initialize
      super("tmux not found in PATH. Install with: brew install tmux (macOS) or apt install tmux (Linux)")
    end

    def code = "tmux_not_found"
  end

  class SessionNotFoundError < DriveError
    attr_reader :session

    def initialize(session)
      @session = session
      super("Session not found: #{session}")
    end

    def code = "session_not_found"

    def to_h
      super.merge(session: @session)
    end
  end

  class SessionExistsError < DriveError
    def initialize(session)
      super("Session already exists: #{session}")
    end

    def code = "session_exists"
  end

  class CommandTimeoutError < DriveError
    attr_reader :session, :timeout

    def initialize(session:, cmd:, timeout:)
      @session = session
      @timeout = timeout
      super("Command timed out after #{timeout}s in session '#{session}': #{cmd[0, 80]}")
    end

    def code = "timeout"

    def to_h
      super.merge(session: @session, timeout: @timeout)
    end
  end

  class TmuxCommandError < DriveError
    def initialize(args:, stderr:)
      super("tmux #{args.join(' ')}: #{stderr}")
    end

    def code = "tmux_error"
  end

  class PatternNotFoundError < DriveError
    def initialize(pattern:, session:, timeout:)
      super("Pattern '#{pattern}' not found in session '#{session}' within #{timeout}s")
    end

    def code = "pattern_not_found"
  end

  class ProcessNotFoundError < DriveError
    def initialize(pid: nil, name: nil)
      msg = if pid
        "Process not found: PID #{pid}"
      elsif name
        "No processes matching: #{name}"
      else
        "No matching processes found"
      end
      super(msg)
    end

    def code = "process_not_found"
  end

  class KillPermissionError < DriveError
    def initialize(pid:)
      super("Permission denied killing PID #{pid}")
    end

    def code = "kill_permission_denied"
  end
end
