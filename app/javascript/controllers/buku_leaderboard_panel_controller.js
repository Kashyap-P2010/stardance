import { Controller } from "@hotwired/stimulus";

// Shows and hides the home leaderboard. It slides in from the right via CSS
// (@starting-style); hiding slides it back out first (data-closing), then
// sets `hidden` once that transition ends.
export default class extends Controller {
  static targets = ["panel", "toggle"];

  disconnect() {
    clearTimeout(this.closeTimer);
  }

  toggle() {
    const open =
      this.panelTarget.hidden || this.panelTarget.hasAttribute("data-closing");
    this.toggleTarget.setAttribute("aria-expanded", String(open));
    clearTimeout(this.closeTimer);

    if (open) {
      this.panelTarget.removeAttribute("data-closing");
      this.panelTarget.hidden = false;
      return;
    }

    this.panelTarget.setAttribute("data-closing", "");
    const finish = () => {
      if (!this.panelTarget.hasAttribute("data-closing")) return;
      this.panelTarget.removeAttribute("data-closing");
      this.panelTarget.hidden = true;
    };
    this.panelTarget.addEventListener("transitionend", finish, { once: true });
    // Reduced motion (no transition) or a missed transitionend still closes.
    this.closeTimer = setTimeout(finish, 400);
  }
}
