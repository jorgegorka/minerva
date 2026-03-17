import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 3000 } }
  static targets = ["terminal", "processes", "status"]

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue)
      if (!response.ok) return

      const data = await response.json()

      if (this.hasTerminalTarget) {
        this.terminalTarget.textContent = data.output
        this.terminalTarget.scrollTop = this.terminalTarget.scrollHeight
      }

      if (this.hasStatusTarget) {
        this.statusTarget.textContent = data.console.status_label
        this.statusTarget.className = `console-status ${data.console.status_css}`
      }

      if (this.hasProcessesTarget) {
        this.processesTarget.replaceChildren(this.buildProcessTable(data.processes))
      }
    } catch {
      // Network error, skip this poll cycle
    }
  }

  buildProcessTable(processes) {
    const table = document.createElement("table")
    table.className = "table"
    table.style.width = "100%"

    const thead = document.createElement("thead")
    const headerRow = document.createElement("tr")
    for (const label of ["PID", "Name", "CPU%", "Memory", "Elapsed", "State"]) {
      const th = document.createElement("th")
      th.textContent = label
      headerRow.appendChild(th)
    }
    thead.appendChild(headerRow)

    const tbody = document.createElement("tbody")
    for (const proc of processes) {
      const row = document.createElement("tr")
      const cells = [
        proc.pid,
        proc.name,
        `${proc.cpu}%`,
        `${proc.memory_mb} MB`,
        proc.elapsed,
        proc.state
      ]
      for (const val of cells) {
        const td = document.createElement("td")
        td.textContent = val
        row.appendChild(td)
      }
      tbody.appendChild(row)
    }

    table.append(thead, tbody)
    return table
  }
}
