# frozen_string_literal: true

require "open3"
require "set"
require_relative "errors"
require_relative "tmux"

module Drive
  module ProcessManager
    ProcessInfo = Data.define(:uid, :pid, :ppid, :name, :command, :cpu, :memory_mb, :elapsed, :state, :cwd, :session) do
      def to_output_h
        h = to_h
        h.delete(:uid)
        h.delete(:session) if session.nil?
        h
      end
    end

    KillResult = Data.define(:killed, :failed, :signal) do
      def to_h
        { ok: failed.empty?, action: "kill", killed: killed, signal: signal, failed: failed }
      end
    end

    module_function

    def parse_ps_output(output)
      lines = output.strip.split("\n")
      return [] if lines.length <= 1

      lines[1..].filter_map do |line|
        fields = line.strip.split(/\s+/, 8)
        next if fields.length < 8

        uid = fields[0].to_i
        pid = fields[1].to_i
        ppid = fields[2].to_i
        cpu = fields[3].to_f
        rss_kb = fields[4].to_i
        elapsed_raw = fields[5]
        state = fields[6]
        command = fields[7]

        name = File.basename(command.split(/\s+/).first.to_s)

        ProcessInfo.new(
          uid: uid, pid: pid, ppid: ppid, name: name, command: command,
          cpu: cpu, memory_mb: (rss_kb / 1024.0).round(1),
          elapsed: normalize_elapsed(elapsed_raw), state: state, cwd: "", session: nil
        )
      end
    end

    def normalize_elapsed(raw)
      if raw.include?("-")
        days, rest = raw.split("-", 2)
        parts = rest.split(":")
        return "#{days}d#{parts[0]}h#{parts[1]}m" if parts.length >= 2
      end

      parts = raw.split(":")
      case parts.length
      when 1 then "#{parts[0].to_i}s"
      when 2 then "#{parts[0].to_i}m#{parts[1].to_i}s"
      when 3 then "#{parts[0].to_i}h#{parts[1].to_i}m"
      else raw
      end
    end

    def list_processes(name: nil, parent: nil, session: nil, cwd: nil)
      stdout, _stderr, _status = Open3.capture3("ps", "-eo", "uid,pid,ppid,pcpu,rss,etime,stat,command")
      processes = parse_ps_output(stdout)

      session_map = session_pid_map
      session_pids = nil

      if session
        root_pids = get_session_pids(session)
        session_pids = Set.new(root_pids)
        root_pids.each { |rpid| add_children(processes, rpid, session_pids) }
      end

      current_uid = Process.uid
      processes = processes.filter_map do |p|
        next if p.uid != current_uid
        next if parent && p.ppid != parent
        next if session_pids && !session_pids.include?(p.pid)

        resolved_cwd = resolve_cwd(p.pid)
        sess = session_map[p.pid]
        updated = ProcessInfo.new(**p.to_h.merge(cwd: resolved_cwd, session: sess))

        next if name && !updated.name.downcase.include?(name.downcase) && !updated.command.downcase.include?(name.downcase)
        next if cwd && !updated.cwd.start_with?(cwd)

        updated
      end

      processes.sort_by(&:pid)
    end

    def kill_process(pid: nil, name: nil, signal: 15, tree: false, graceful_timeout: 5.0)
      targets = []
      if pid
        targets << pid
      elsif name
        list_processes(name: name).each { |p| targets << p.pid }
      end
      raise ProcessNotFoundError.new(pid: pid, name: name) if targets.empty?

      all_pids = []
      targets.each do |target_pid|
        next if target_pid <= 1 || target_pid == Process.pid
        all_pids << target_pid
        if tree
          stdout, = Open3.capture3("ps", "-eo", "pid,ppid")
          children = find_descendants(parse_pid_ppid(stdout), target_pid)
          all_pids.concat(children.reverse)
        end
      end

      killed = []
      failed = []

      all_pids.uniq.each do |p|
        begin
          Process.kill(signal, p)
        rescue Errno::ESRCH
          killed << p
        rescue Errno::EPERM
          failed << { pid: p, error: "permission_denied" }
        end
      end

      deadline = Time.now + graceful_timeout
      remaining = all_pids.uniq - killed - failed.map { |f| f[:pid] }
      until remaining.empty? || Time.now >= deadline
        sleep 0.2
        remaining.reject! do |p|
          begin
            Process.kill(0, p)
            false
          rescue Errno::ESRCH
            killed << p
            true
          rescue Errno::EPERM
            false
          end
        end
      end

      if signal == 15
        remaining.each do |p|
          begin
            Process.kill(9, p)
            killed << p
          rescue Errno::ESRCH
            killed << p
          rescue Errno::EPERM
            failed << { pid: p, error: "permission_denied" }
          end
        end
      end

      KillResult.new(killed: killed.uniq, failed: failed, signal: signal)
    end

    def process_tree(pid)
      stdout, = Open3.capture3("ps", "-eo", "pid,ppid,comm")
      all = parse_pid_ppid_name(stdout)
      entry = all.find { |e| e[:pid] == pid }
      raise ProcessNotFoundError.new(pid: pid) unless entry
      build_tree_node(all, pid, entry[:name])
    end

    def build_tree(processes, root_pid)
      by_ppid = processes.group_by(&:ppid)
      root = processes.find { |p| p.pid == root_pid }
      return nil unless root
      build_tree_recursive(by_ppid, root)
    end

    def process_snapshot(pids)
      stdout, = Open3.capture3("ps", "-eo", "uid,pid,ppid,pcpu,rss,etime,stat,command")
      all = parse_ps_output(stdout)
      pid_set = pids.to_set
      all.select { |p| pid_set.include?(p.pid) }
    end

    def descendant_pids(root_pids)
      stdout, = Open3.capture3("ps", "-eo", "pid,ppid")
      entries = parse_pid_ppid(stdout)
      all_pids = root_pids.dup
      root_pids.each { |rp| all_pids.concat(find_descendants(entries, rp)) }
      all_pids.uniq
    end

    def session_pid_map
      pid_map = {}
      result = Tmux.run(["list-panes", "-a", "-F", '#{session_name}|||#{pane_pid}'], check: false)
      return pid_map unless result.status.success?

      result.stdout.strip.split("\n").each do |line|
        parts = line.split("|||")
        pid_map[parts[1].to_i] = parts[0] if parts.length == 2
      end
      pid_map
    rescue DriveError
      {}
    end

    def get_session_pids(session_name)
      result = Tmux.run(["list-panes", "-t", session_name, "-F", '#{pane_pid}'], check: false)
      return [] unless result.status.success?
      result.stdout.strip.split("\n").map { |l| l.strip.to_i }.select(&:positive?)
    rescue DriveError
      []
    end

    def resolve_cwd(pid)
      if RUBY_PLATFORM.include?("linux")
        File.readlink("/proc/#{pid}/cwd") rescue ""
      elsif RUBY_PLATFORM.include?("darwin")
        stdout, _, status = Open3.capture3("lsof", "-a", "-d", "cwd", "-Fn", "-p", pid.to_s)
        if status.success?
          line = stdout.lines.find { |l| l.start_with?("n") }
          line ? line[1..].strip : ""
        else
          ""
        end
      else
        ""
      end
    end

    def add_children(processes, parent_pid, pid_set)
      processes.each do |p|
        if p.ppid == parent_pid && !pid_set.include?(p.pid)
          pid_set.add(p.pid)
          add_children(processes, p.pid, pid_set)
        end
      end
    end

    def parse_pid_ppid(output)
      output.strip.split("\n")[1..].filter_map do |line|
        parts = line.strip.split(/\s+/, 2)
        next if parts.length < 2
        { pid: parts[0].to_i, ppid: parts[1].to_i }
      end
    end

    def parse_pid_ppid_name(output)
      output.strip.split("\n")[1..].filter_map do |line|
        parts = line.strip.split(/\s+/, 3)
        next if parts.length < 3
        { pid: parts[0].to_i, ppid: parts[1].to_i, name: parts[2] }
      end
    end

    def find_descendants(entries, pid)
      children = entries.select { |e| e[:ppid] == pid }.map { |e| e[:pid] }
      children + children.flat_map { |c| find_descendants(entries, c) }
    end

    def build_tree_node(all, pid, name)
      children = all.select { |e| e[:ppid] == pid }
      { pid: pid, name: name, children: children.map { |c| build_tree_node(all, c[:pid], c[:name]) } }
    end

    def build_tree_recursive(by_ppid, proc_info)
      children = (by_ppid[proc_info.pid] || []).map { |c| build_tree_recursive(by_ppid, c) }
      { pid: proc_info.pid, name: proc_info.name, children: children }
    end

    private_class_method :resolve_cwd, :add_children,
                         :parse_pid_ppid, :parse_pid_ppid_name,
                         :find_descendants, :build_tree_node, :build_tree_recursive
  end
end
