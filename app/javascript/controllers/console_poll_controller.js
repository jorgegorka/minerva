import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String, interval: { type: Number, default: 3000 } }
  static targets = ["list"]

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

      const consoles = await response.json()
      const container = this.listTarget
      container.replaceChildren(...this.buildCards(consoles))
    } catch {
      // Network error, skip this poll cycle
    }
  }

  buildCards(consoles) {
    if (consoles.length === 0) {
      const card = document.createElement("div")
      card.className = "card"
      const p = document.createElement("p")
      p.textContent = "No active tmux sessions found."
      const hint = document.createElement("p")
      hint.className = "txt-subtle"
      hint.textContent = "Start a session with: bin/drive create <name>"
      card.append(p, hint)
      return [card]
    }

    return consoles.map(c => {
      const link = document.createElement("a")
      link.href = `/consoles/${encodeURIComponent(c.name)}`
      link.className = "card card--interactive card--compact"
      link.style.cssText = "display: block; text-decoration: none; color: inherit;"

      const header = document.createElement("div")
      header.style.cssText = "display: flex; justify-content: space-between; align-items: center;"

      const title = document.createElement("h3")
      title.style.margin = "0"
      title.textContent = c.name

      const badge = document.createElement("span")
      badge.className = `console-status ${c.status_css}`
      badge.textContent = c.status_label

      header.append(title, badge)

      const meta = document.createElement("p")
      meta.className = "txt-subtle"
      meta.style.cssText = "margin-block-start: var(--space-sm); margin-block-end: 0;"
      const windows = c.windows === 1 ? "1 window" : `${c.windows} windows`
      const attached = c.attached ? "Attached" : "Detached"
      meta.textContent = `${windows} · ${attached} · Created ${c.created}`

      link.append(header, meta)
      return link
    })
  }
}
