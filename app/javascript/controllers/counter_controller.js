import { Controller } from "@hotwired/stimulus"

// Animated Counter Controller for dashboard statistics
export default class extends Controller {
  static targets = ["number"]
  static values = {
    end: Number,
    duration: { type: Number, default: 2000 },
    delay: { type: Number, default: 0 },
    prefix: { type: String, default: "" },
    suffix: { type: String, default: "" },
    decimals: { type: Number, default: 0 }
  }

  connect() {
    this.startValue = 0
    this.currentValue = 0
    this.animationFrame = null

    // Set up intersection observer for scroll-triggered animation
    this.setupIntersectionObserver()
  }

  disconnect() {
    if (this.animationFrame) {
      cancelAnimationFrame(this.animationFrame)
    }
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  setupIntersectionObserver() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting && !this.hasAnimated) {
            this.hasAnimated = true
            setTimeout(() => {
              this.startAnimation()
            }, this.delayValue)
          }
        })
      },
      {
        threshold: 0.5,
        rootMargin: "0px"
      }
    )

    this.observer.observe(this.element)
  }

  startAnimation() {
    const startTime = performance.now()

    const animate = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / this.durationValue, 1)

      // Use easing function for smooth animation
      const easedProgress = this.easeOutQuart(progress)
      this.currentValue = this.startValue + (this.endValue - this.startValue) * easedProgress

      this.updateDisplay()

      if (progress < 1) {
        this.animationFrame = requestAnimationFrame(animate)
      } else {
        // Ensure we end on the exact value
        this.currentValue = this.endValue
        this.updateDisplay()
        this.dispatch("completed", { detail: { value: this.endValue } })
      }
    }

    this.animationFrame = requestAnimationFrame(animate)
  }

  updateDisplay() {
    const formattedValue = this.formatNumber(this.currentValue)
    const displayValue = `${this.prefixValue}${formattedValue}${this.suffixValue}`

    if (this.hasNumberTarget) {
      this.numberTarget.textContent = displayValue
    } else {
      this.element.textContent = displayValue
    }

    // Add visual feedback during animation
    this.element.classList.add("animating")
    if (this.currentValue === this.endValue) {
      this.element.classList.remove("animating")
      this.element.classList.add("completed")
    }
  }

  formatNumber(value) {
    // Format with proper decimals and thousand separators
    const rounded = Number(value.toFixed(this.decimalsValue))

    if (this.decimalsValue > 0) {
      return rounded.toLocaleString('en-US', {
        minimumFractionDigits: this.decimalsValue,
        maximumFractionDigits: this.decimalsValue
      })
    } else {
      return Math.round(rounded).toLocaleString('en-US')
    }
  }

  // Easing function for smooth animation
  easeOutQuart(t) {
    return 1 - Math.pow(1 - t, 4)
  }

  // Allow manual trigger
  animate() {
    this.hasAnimated = false
    this.startAnimation()
  }

  // Update the end value and re-animate
  updateValue(newValue) {
    this.startValue = this.currentValue
    this.endValue = newValue
    this.startAnimation()
  }
}