---
name: drive
description: Use when you need to automate terminal sessions, run commands in tmux, manage processes, or orchestrate parallel command execution across multiple sessions
---

# Drive — Terminal Automation via tmux

Run from project root: `bin/drive <command> [args] [--json]`

Drive gives you full programmatic control over tmux sessions — creating terminals, running commands, reading output, and orchestrating parallel workloads.

## Commands

### session — Manage tmux sessions

```bash
bin/drive session create agent-1 --json                      # Opens a Terminal window (headed — macOS default)
bin/drive session create agent-1 --detach --json             # Headless (no Terminal window)
bin/drive session create agent-1 --window build --json       # Named window, headed
bin/drive session create agent-1 --dir /tmp/work --json      # Set working directory
bin/drive session list --json                                # List all sessions
bin/drive session kill agent-1 --json                        # Kill a session
```

**Default is headed on macOS** — a new Terminal.app window opens attached to the session so you can watch live. On Linux, sessions are always detached. Use `--detach` when you need a headless session.

### run — Execute command and wait for completion

Uses sentinel protocol (`__DONE_<token>:<exit_code>`) for reliable completion detection.

```bash
bin/drive run agent-1 "npm test" --json                     # Run and wait
bin/drive run agent-1 "make build" --timeout 120 --json     # Custom timeout
bin/drive run agent-1 "ls" --pane 1 --json                  # Target specific pane
```

Returns: exit code, captured output between sentinels.

### send — Raw keystrokes (no completion waiting)

For interactive tools (vim, ipython, etc.) where sentinel detection would interfere.

```bash
bin/drive send agent-1 "vim file.txt" --json                # Send command
bin/drive send agent-1 ":wq" --json                         # Send vim command
bin/drive send agent-1 "y" --no-enter --json                # Send without Enter
```

### logs — Capture pane output

```bash
bin/drive logs agent-1 --json                               # Visible pane content
bin/drive logs agent-1 --lines 500 --json                   # Last 500 lines of scrollback
bin/drive logs agent-1 --pane 1 --json                      # Specific pane
```

### poll — Wait for pattern in output

```bash
bin/drive poll agent-1 --until "BUILD SUCCESS" --json                   # Wait for pattern
bin/drive poll agent-1 --until "ready" --timeout 60 --json              # With timeout
bin/drive poll agent-1 --until "error|success" --interval 2.0 --json   # Custom interval
```

Pattern is a regex. Returns matched text and full pane content.

### fanout — Parallel execution

```bash
bin/drive fanout "npm test" --targets agent-1,agent-2,agent-3 --json         # Same command, multiple sessions
bin/drive fanout "git pull" --targets a1,a2,a3 --timeout 30 --json           # With timeout
```

Runs command in all target sessions concurrently using threads. Returns ordered results.

### proc — Process management

```bash
bin/drive proc list --json                                    # All user processes
bin/drive proc list --name claude --json                      # Filter by name
bin/drive proc list --session job-abc123 --json               # Processes in a tmux session
bin/drive proc kill 12345 --json                              # Kill by PID (SIGTERM → wait → SIGKILL)
bin/drive proc kill --name "claude" --json                    # Kill all matching name
bin/drive proc kill 12345 --tree --json                       # Kill PID and all children
bin/drive proc tree 12345 --json                              # Show process tree from PID
bin/drive proc top --session job-abc123 --json                # Resource snapshot for session
```

## Key Patterns

- **Create sessions first** — `bin/drive session create` before running commands
- **Use `run` for commands that complete** — It waits and gives you exit code + output
- **Use `send` for interactive tools** — vim, ipython, anything that doesn't "finish"
- **Use `poll` to wait for async events** — Watch for build completion, server startup, etc.
- **Use `logs` to inspect** — Check what happened in a pane
- **Use `fanout` for parallel work** — Run same command across multiple sessions
- **Use `proc` for process management** — List, kill, and inspect processes
- **Use `--json` always** — Structured output for reliable parsing
- **Write all files to /tmp** — Any JSON, logs, or other files you generate must go to `/tmp/`

## Sentinel Protocol

Drive wraps commands with markers: `echo "__START_<token>" ; <cmd> ; echo "__DONE_<token>:$?"`

This gives:
- Reliable completion detection (no guessing)
- Accurate exit code capture
- Clean output extraction (only content between markers)
