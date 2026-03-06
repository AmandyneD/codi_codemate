import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scroll()
    new MutationObserver(() => this.scroll()).observe(this.element, { childList: true })
  }

  scroll() {
    this.element.scrollTop = this.element.scrollHeight
  }
}
