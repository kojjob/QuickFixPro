import { Controller } from "@hotwired/stimulus"

// Responsive Sidebar Controller with mobile gestures
export default class extends Controller {
  static targets = ["sidebar", "overlay", "toggleButton"]
  static values = {
    open: { type: Boolean, default: false },
    breakpoint: { type: Number, default: 1024 }
  }

  connect() {
    this.setupResponsive()
    this.setupSwipeGestures()
    this.setupKeyboardHandling()
    this.restoreState()
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    this.removeSwipeListeners()
    this.removeKeyboardListeners()
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateSidebar()
    this.saveState()
  }

  open() {
    this.openValue = true
    this.updateSidebar()
    this.saveState()
  }

  close() {
    this.openValue = false
    this.updateSidebar()
    this.saveState()
  }

  updateSidebar() {
    const isMobile = window.innerWidth < this.breakpointValue

    if (this.hasSidebarTarget) {
      if (this.openValue) {
        this.sidebarTarget.classList.remove('-translate-x-full', 'lg:translate-x-0')
        this.sidebarTarget.classList.add('translate-x-0')

        if (isMobile) {
          this.showOverlay()
          this.trapFocus()
        }
      } else {
        this.sidebarTarget.classList.add('-translate-x-full', 'lg:translate-x-0')
        this.sidebarTarget.classList.remove('translate-x-0')

        if (isMobile) {
          this.hideOverlay()
          this.releaseFocus()
        }
      }
    }

    // Update toggle button
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.setAttribute('aria-expanded', this.openValue)
      this.animateToggleButton()
    }

    // Dispatch event for other components
    this.dispatch("toggled", { detail: { open: this.openValue } })
  }

  showOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('hidden')
      this.overlayTarget.classList.add('block')

      // Animate overlay
      requestAnimationFrame(() => {
        this.overlayTarget.classList.add('bg-opacity-50')
      })
    }
  }

  hideOverlay() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.classList.remove('bg-opacity-50')

      // Wait for animation
      setTimeout(() => {
        this.overlayTarget.classList.add('hidden')
        this.overlayTarget.classList.remove('block')
      }, 300)
    }
  }

  setupResponsive() {
    // Watch for window resize
    this.resizeObserver = new ResizeObserver(() => {
      const isMobile = window.innerWidth < this.breakpointValue

      if (!isMobile && this.openValue) {
        // Close sidebar when transitioning to desktop
        this.hideOverlay()
        this.releaseFocus()
      }
    })

    this.resizeObserver.observe(document.body)
  }

  setupSwipeGestures() {
    let touchStartX = 0
    let touchEndX = 0
    let touchStartY = 0
    let touchEndY = 0

    this.handleTouchStart = (e) => {
      touchStartX = e.changedTouches[0].screenX
      touchStartY = e.changedTouches[0].screenY
    }

    this.handleTouchEnd = (e) => {
      touchEndX = e.changedTouches[0].screenX
      touchEndY = e.changedTouches[0].screenY
      this.handleSwipe(touchStartX, touchEndX, touchStartY, touchEndY)
    }

    // Add swipe listeners
    if (this.hasSidebarTarget) {
      this.sidebarTarget.addEventListener('touchstart', this.handleTouchStart)
      this.sidebarTarget.addEventListener('touchend', this.handleTouchEnd)
    }

    // Edge swipe to open
    document.addEventListener('touchstart', (e) => {
      if (e.changedTouches[0].screenX < 20 && !this.openValue) {
        touchStartX = e.changedTouches[0].screenX
        touchStartY = e.changedTouches[0].screenY
      }
    })

    document.addEventListener('touchend', (e) => {
      if (touchStartX < 20 && !this.openValue) {
        touchEndX = e.changedTouches[0].screenX
        touchEndY = e.changedTouches[0].screenY
        this.handleSwipe(touchStartX, touchEndX, touchStartY, touchEndY)
      }
    })
  }

  handleSwipe(startX, endX, startY, endY) {
    const diffX = endX - startX
    const diffY = endY - startY
    const threshold = 50

    // Only handle horizontal swipes
    if (Math.abs(diffX) > Math.abs(diffY) && Math.abs(diffX) > threshold) {
      if (diffX > 0 && !this.openValue) {
        // Swipe right - open sidebar
        this.open()
      } else if (diffX < 0 && this.openValue) {
        // Swipe left - close sidebar
        this.close()
      }
    }
  }

  removeSwipeListeners() {
    if (this.hasSidebarTarget) {
      this.sidebarTarget.removeEventListener('touchstart', this.handleTouchStart)
      this.sidebarTarget.removeEventListener('touchend', this.handleTouchEnd)
    }
  }

  setupKeyboardHandling() {
    this.handleKeyDown = (e) => {
      if (e.key === 'Escape' && this.openValue) {
        this.close()
      }
    }

    document.addEventListener('keydown', this.handleKeyDown)
  }

  removeKeyboardListeners() {
    document.removeEventListener('keydown', this.handleKeyDown)
  }

  trapFocus() {
    if (!this.hasSidebarTarget) return

    // Get all focusable elements in sidebar
    const focusableElements = this.sidebarTarget.querySelectorAll(
      'a[href], button, textarea, input[type="text"], input[type="radio"], input[type="checkbox"], select'
    )

    if (focusableElements.length > 0) {
      this.firstFocusable = focusableElements[0]
      this.lastFocusable = focusableElements[focusableElements.length - 1]

      // Focus first element
      this.firstFocusable.focus()

      // Add focus trap handler
      this.handleFocusTrap = (e) => {
        if (e.key === 'Tab') {
          if (e.shiftKey) {
            if (document.activeElement === this.firstFocusable) {
              e.preventDefault()
              this.lastFocusable.focus()
            }
          } else {
            if (document.activeElement === this.lastFocusable) {
              e.preventDefault()
              this.firstFocusable.focus()
            }
          }
        }
      }

      this.sidebarTarget.addEventListener('keydown', this.handleFocusTrap)
    }
  }

  releaseFocus() {
    if (this.handleFocusTrap && this.hasSidebarTarget) {
      this.sidebarTarget.removeEventListener('keydown', this.handleFocusTrap)
    }
  }

  animateToggleButton() {
    if (!this.hasToggleButtonTarget) return

    // Add rotation animation
    this.toggleButtonTarget.classList.add('rotate-180')
    setTimeout(() => {
      this.toggleButtonTarget.classList.remove('rotate-180')
    }, 300)
  }

  saveState() {
    // Save sidebar state to localStorage
    localStorage.setItem('sidebarOpen', this.openValue)
  }

  restoreState() {
    // Restore sidebar state from localStorage
    const saved = localStorage.getItem('sidebarOpen')
    if (saved !== null) {
      this.openValue = saved === 'true'
      this.updateSidebar()
    }
  }

  // Handle overlay click
  overlayClick(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }
}