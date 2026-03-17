# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../../lib/drive/process_manager"

class Drive::ProcessManagerTest < Minitest::Test
  SAMPLE_PS_OUTPUT = <<~PS
      UID  PID  PPID  %CPU   RSS     ELAPSED STAT COMMAND
      501  100     1   2.5 51200       01:30 S    /usr/bin/ruby app.rb
      501  200   100   0.0  1024    1-02:15:30 S    node server.js
      501  300   100  15.3 204800      00:45 R    python train.py
  PS

  def test_parse_ps_output
    processes = Drive::ProcessManager.parse_ps_output(SAMPLE_PS_OUTPUT)
    assert_equal 3, processes.length

    ruby_proc = processes.find { |p| p.pid == 100 }
    assert_equal 501, ruby_proc.uid
    assert_equal 1, ruby_proc.ppid
    assert_equal "ruby", ruby_proc.name
    assert_in_delta 2.5, ruby_proc.cpu
    assert_in_delta 50.0, ruby_proc.memory_mb
    assert_match(/1m30s/, ruby_proc.elapsed)
    assert_equal "S", ruby_proc.state
    assert_equal "/usr/bin/ruby app.rb", ruby_proc.command
  end

  def test_parse_ps_elapsed_with_days
    processes = Drive::ProcessManager.parse_ps_output(SAMPLE_PS_OUTPUT)
    node_proc = processes.find { |p| p.pid == 200 }
    assert_match(/1d/, node_proc.elapsed)
  end

  def test_parse_ps_output_empty
    processes = Drive::ProcessManager.parse_ps_output("  UID  PID  PPID  %CPU   RSS     ELAPSED STAT COMMAND\n")
    assert_equal 0, processes.length
  end

  def test_build_process_tree
    processes = [
      Drive::ProcessManager::ProcessInfo.new(uid: 0, pid: 1, ppid: 0, name: "init", command: "init", cpu: 0, memory_mb: 0, elapsed: "0s", state: "S", cwd: "", session: nil),
      Drive::ProcessManager::ProcessInfo.new(uid: 501, pid: 100, ppid: 1, name: "ruby", command: "ruby", cpu: 0, memory_mb: 0, elapsed: "0s", state: "S", cwd: "", session: nil),
      Drive::ProcessManager::ProcessInfo.new(uid: 501, pid: 200, ppid: 100, name: "node", command: "node", cpu: 0, memory_mb: 0, elapsed: "0s", state: "S", cwd: "", session: nil),
    ]
    tree = Drive::ProcessManager.build_tree(processes, 100)
    assert_equal 100, tree[:pid]
    assert_equal "ruby", tree[:name]
    assert_equal 1, tree[:children].length
    assert_equal 200, tree[:children][0][:pid]
  end
end

class Drive::ProcessManagerIntegrationTest < Minitest::Test
  def test_list_processes_returns_current_process
    processes = Drive::ProcessManager.list_processes
    pids = processes.map(&:pid)
    assert_includes pids, Process.pid
  end

  def test_list_processes_filter_by_name
    processes = Drive::ProcessManager.list_processes(name: "ruby")
    assert processes.length > 0
    processes.each do |p|
      assert(p.name.downcase.include?("ruby") || p.command.downcase.include?("ruby"))
    end
  end
end
