# frozen_string_literal: true

require "thor"
require_relative "errors"
require_relative "output"
require_relative "tmux"
require_relative "sentinel"
require_relative "process_manager"

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

  class ProcCmd < Thor
    namespace :proc

    desc "list", "List processes owned by current user"
    option :name, type: :string, desc: "Filter by process name"
    option :session, type: :string, desc: "Filter by tmux session name"
    option :parent, type: :numeric, desc: "Filter by parent PID"
    option :cwd, type: :string, desc: "Filter by working directory"
    option :json, type: :boolean, default: false, desc: "Output JSON"
    def list
      processes = ProcessManager.list_processes(
        name: options[:name], parent: options[:parent]&.to_i,
        session: options[:session], cwd: options[:cwd]
      )
      if options[:json]
        Output.emit({ ok: true, count: processes.length, processes: processes.map(&:to_output_h) }, json: true, human_lines: "")
      else
        if processes.empty?
          puts "No matching processes."
        else
          processes.each do |p|
            sess = p.session ? "  [#{p.session}]" : ""
            cpu = p.cpu ? format("%5.1f%%", p.cpu) : "    -  "
            cmd = p.command.length > 60 ? "...#{p.command[-60..]}" : p.command
            puts format("  %-8d %-20s %s  %7.1fMB  %8s  %s%s", p.pid, p.name, cpu, p.memory_mb, p.elapsed, p.state, sess)
            puts "           #{cmd}"
          end
        end
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "kill [PID]", "Kill a process by PID or name"
    option :name, type: :string, desc: "Kill all processes matching name"
    option :signal, type: :numeric, default: 15
    option :force, type: :boolean, default: false
    option :tree, type: :boolean, default: false
    option :json, type: :boolean, default: false
    def kill(pid = nil)
      sig = options[:force] ? 9 : options[:signal]
      if pid.nil? && options[:name].nil?
        Output.emit_error(DriveError.new("Provide a PID argument or --name to kill"), json: options[:json])
        return
      end
      result = ProcessManager.kill_process(pid: pid&.to_i, name: options[:name], signal: sig, tree: options[:tree])
      if options[:json]
        Output.emit(result.to_h, json: true, human_lines: "")
      else
        killed_str = result.killed.join(", ")
        puts killed_str.empty? ? "No processes killed." : "Killed: #{killed_str}"
        result.failed.each { |f| puts "  Failed: PID #{f[:pid]} (#{f[:error]})" }
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "tree PID", "Show process tree from PID"
    option :session, type: :string
    option :json, type: :boolean, default: false
    def tree(pid = nil)
      if pid.nil? && options[:session].nil?
        Output.emit_error(DriveError.new("Provide a PID argument or --session"), json: options[:json])
        return
      end
      if options[:session]
        pids = ProcessManager.get_session_pids(options[:session])
        raise ProcessNotFoundError.new(name: "session:#{options[:session]}") if pids.empty?
        pid = pids.first.to_s
      end
      tree_data = ProcessManager.process_tree(pid.to_i)
      if options[:json]
        Output.emit({ ok: true, root: pid.to_i, tree: tree_data }, json: true, human_lines: "")
      else
        print_tree(tree_data)
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    desc "top", "Resource snapshot for PIDs or session"
    option :pid, type: :string, desc: "Comma-separated PIDs"
    option :session, type: :string
    option :json, type: :boolean, default: false
    def top
      pid_list = []
      if options[:session]
        root_pids = ProcessManager.get_session_pids(options[:session])
        pid_list = ProcessManager.descendant_pids(root_pids)
      elsif options[:pid]
        pid_list = options[:pid].split(",").map { |p| p.strip.to_i }.select(&:positive?)
      end
      if pid_list.empty?
        Output.emit_error(DriveError.new("Provide --pid or --session"), json: options[:json])
        return
      end
      snapshot = ProcessManager.process_snapshot(pid_list)
      if options[:json]
        Output.emit({ ok: true, snapshot: snapshot.map(&:to_output_h) }, json: true, human_lines: "")
      else
        if snapshot.empty?
          puts "No processes found."
        else
          snapshot.each do |p|
            cpu = p.cpu ? format("%5.1f%%", p.cpu) : "    -  "
            puts format("  %-8d %-20s %s  %7.1fMB  %8s  %s", p.pid, p.name, cpu, p.memory_mb, p.elapsed, p.state)
          end
        end
      end
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end

    private

    def print_tree(node, indent = 0)
      prefix = indent > 0 ? ("  " * indent + "└─ ") : ""
      puts "#{prefix}#{node[:pid]} #{node[:name]}"
      (node[:children] || []).each { |c| print_tree(c, indent + 1) }
    end
  end

  class Cli < Thor
    desc "session SUBCOMMAND", "Manage tmux sessions"
    subcommand "session", Session

    desc "proc SUBCOMMAND", "Manage processes"
    subcommand "proc", ProcCmd

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
    rescue DriveError => e
      Output.emit_error(e, json: options[:json])
    end
  end
end
