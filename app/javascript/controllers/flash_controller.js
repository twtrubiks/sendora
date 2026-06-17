import { Controller } from "@hotwired/stimulus"

// 成功訊息 3 秒後自動消失
export default class extends Controller {
  static values = { timeout: { type: Number, default: 3000 } }

  connect() {
    this.timer = setTimeout(() => this.element.remove(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
