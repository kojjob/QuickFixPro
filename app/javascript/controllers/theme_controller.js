import { Controller } from "@hotwired/stimulus"

// Theme Controller for dark/light mode switching
export default class extends Controller {
  static targets = ["icon", "text"]
  static values = {
    current: { type: String, default: "light" }
  }

  connect() {
    // Initialize theme from localStorage or system preference
    this.initializeTheme()
    this.setupSystemThemeListener()
    this.updateUI()
  }

  disconnect() {
    if (this.mediaQuery) {
      this.mediaQuery.removeEventListener('change', this.handleSystemThemeChange)
    }
  }

  initializeTheme() {
    // Check localStorage first
    const savedTheme = localStorage.getItem('theme')

    if (savedTheme) {
      this.currentValue = savedTheme
    } else {
      // Use system preference
      this.currentValue = this.getSystemTheme()
    }

    this.applyTheme()
  }

  getSystemTheme() {
    if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return 'dark'
    }
    return 'light'
  }

  setupSystemThemeListener() {
    if (window.matchMedia) {
      this.mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      this.handleSystemThemeChange = (e) => {
        if (!localStorage.getItem('theme')) {
          this.currentValue = e.matches ? 'dark' : 'light'
          this.applyTheme()
          this.updateUI()
        }
      }
      this.mediaQuery.addEventListener('change', this.handleSystemThemeChange)
    }
  }

  toggle() {
    // Toggle between light and dark
    this.currentValue = this.currentValue === 'light' ? 'dark' : 'light'

    // Save preference
    localStorage.setItem('theme', this.currentValue)

    // Apply theme with animation
    this.applyThemeWithTransition()
    this.updateUI()

    // Dispatch event for other components
    this.dispatch("changed", { detail: { theme: this.currentValue } })
  }

  setTheme(event) {
    const theme = event.params.theme

    if (theme === 'system') {
      // Clear localStorage and use system preference
      localStorage.removeItem('theme')
      this.currentValue = this.getSystemTheme()
    } else {
      this.currentValue = theme
      localStorage.setItem('theme', theme)
    }

    this.applyThemeWithTransition()
    this.updateUI()
    this.dispatch("changed", { detail: { theme: this.currentValue } })
  }

  applyTheme() {
    const html = document.documentElement

    if (this.currentValue === 'dark') {
      html.classList.add('dark')
      html.setAttribute('data-theme', 'dark')
    } else {
      html.classList.remove('dark')
      html.setAttribute('data-theme', 'light')
    }
  }

  applyThemeWithTransition() {
    const html = document.documentElement

    // Add transition class
    html.classList.add('theme-transition')

    // Apply theme
    this.applyTheme()

    // Remove transition class after animation
    setTimeout(() => {
      html.classList.remove('theme-transition')
    }, 300)
  }

  updateUI() {
    // Update button icon
    if (this.hasIconTarget) {
      this.iconTarget.innerHTML = this.currentValue === 'dark' ? this.getSunIcon() : this.getMoonIcon()
    }

    // Update button text if present
    if (this.hasTextTarget) {
      this.textTarget.textContent = this.currentValue === 'dark' ? 'Light Mode' : 'Dark Mode'
    }

    // Update button aria-label
    this.element.setAttribute('aria-label', `Switch to ${this.currentValue === 'dark' ? 'light' : 'dark'} mode`)

    // Add visual feedback
    this.element.classList.add('theme-switching')
    setTimeout(() => {
      this.element.classList.remove('theme-switching')
    }, 200)
  }

  getSunIcon() {
    return `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z">
        </path>
      </svg>
    `
  }

  getMoonIcon() {
    return `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
              d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z">
        </path>
      </svg>
    `
  }
}