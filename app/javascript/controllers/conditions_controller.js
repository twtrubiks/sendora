import { Controller } from "@hotwired/stimulus"

// 分群的動態條件列:新增 / 移除列、依條件類型切換對應的值輸入框
export default class extends Controller {
  static targets = ["rows", "template"]

  add() {
    this.rowsTarget.insertAdjacentHTML("beforeend", this.templateTarget.innerHTML)
  }

  remove(event) {
    event.target.closest("[data-condition-row]").remove()
  }

  switchType(event) {
    const row = event.target.closest("[data-condition-row]")
    const type = this.valueTypeFor(event.target.value)

    row.querySelectorAll("[data-value-input]").forEach(input => {
      const active = input.dataset.valueInput === type
      input.hidden = !active
      input.disabled = !active
    })
  }

  valueTypeFor(key) {
    if (key === "tag") return "tag"
    if (key.endsWith("_after") || key.endsWith("_before")) return "date"
    return "number"
  }
}
