import { Controller } from "@hotwired/stimulus"

// 放在 turbo-frame 內,每隔一段時間重新載入該 frame(匯入進度用)
export default class extends Controller {
  static values = { interval: { type: Number, default: 3000 } }

  connect() {
    this.frame = this.element.closest("turbo-frame")
    this.timer = setInterval(() => this.frame?.reload(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }
}
