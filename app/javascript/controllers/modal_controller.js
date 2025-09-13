import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "backdrop", "content", "title", "body", "footer"]
  static values = { 
    size: String,
    closable: { type: Boolean, default: true },
    backdrop: { type: Boolean, default: true }
  }

  connect() {
    this.boundKeyHandler = this.handleKeydown.bind(this)
    this.boundOutsideClick = this.handleOutsideClick.bind(this)
  }

  disconnect() {
    this.removeEventListeners()
  }

  open(event) {
    // Prevent default if called from a link
    if (event?.preventDefault) {
      event.preventDefault()
    }

    this.containerTarget.classList.remove("hidden")
    this.containerTarget.classList.add("flex")
    
    // Add modal size class
    this.applySize()
    
    // Animate in
    requestAnimationFrame(() => {
      this.backdropTarget.classList.remove("opacity-0")
      this.backdropTarget.classList.add("opacity-100")
      
      this.contentTarget.classList.remove("opacity-0", "scale-95", "translate-y-4", "sm:translate-y-0", "sm:scale-95")
      this.contentTarget.classList.add("opacity-100", "scale-100", "translate-y-0", "sm:scale-100")
    })

    this.addEventListeners()
    this.focusFirstElement()
    document.body.style.overflow = 'hidden'
  }

  close(event) {
    if (event?.preventDefault) {
      event.preventDefault()
    }

    if (!this.closableValue) {
      return
    }

    // Animate out
    this.backdropTarget.classList.remove("opacity-100")
    this.backdropTarget.classList.add("opacity-0")
    
    this.contentTarget.classList.remove("opacity-100", "scale-100", "translate-y-0", "sm:scale-100")
    this.contentTarget.classList.add("opacity-0", "scale-95", "translate-y-4", "sm:translate-y-0", "sm:scale-95")

    // Hide after animation
    setTimeout(() => {
      this.containerTarget.classList.add("hidden")
      this.containerTarget.classList.remove("flex")
      this.removeEventListeners()
      document.body.style.overflow = ''
      
      // Dispatch close event
      this.dispatch("close")
    }, 150)
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.closableValue) {
      this.close()
    }
  }

  handleOutsideClick(event) {
    if (!this.backdropValue) return
    
    if (event.target === this.backdropTarget && this.closableValue) {
      this.close()
    }
  }

  addEventListeners() {
    document.addEventListener("keydown", this.boundKeyHandler)
    if (this.backdropValue) {
      this.backdropTarget.addEventListener("click", this.boundOutsideClick)
    }
  }

  removeEventListeners() {
    document.removeEventListener("keydown", this.boundKeyHandler)
    if (this.backdropValue) {
      this.backdropTarget.removeEventListener("click", this.boundOutsideClick)
    }
  }

  applySize() {
    const sizeClasses = {
      'sm': 'max-w-sm',
      'md': 'max-w-md',
      'lg': 'max-w-lg',
      'xl': 'max-w-xl',
      '2xl': 'max-w-2xl',
      '3xl': 'max-w-3xl',
      '4xl': 'max-w-4xl',
      '5xl': 'max-w-5xl',
      '6xl': 'max-w-6xl',
      'full': 'max-w-full'
    }
    
    const sizeClass = sizeClasses[this.sizeValue] || 'max-w-lg'
    
    // Remove all size classes first
    Object.values(sizeClasses).forEach(cls => {
      this.contentTarget.classList.remove(cls)
    })
    
    // Add the appropriate size class
    this.contentTarget.classList.add(sizeClass)
  }

  focusFirstElement() {
    const focusableElements = this.contentTarget.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
    )
    
    if (focusableElements.length > 0) {
      focusableElements[0].focus()
    }
  }

  // Dynamic content loading
  loadContent(url) {
    if (!url) return
    
    this.showLoading()
    
    fetch(url, {
      headers: {
        "Accept": "text/vnd.turbo-stream.html, text/html, application/xhtml+xml",
        "Turbo-Frame": this.contentTarget.id || "modal-content"
      }
    })
    .then(response => response.text())
    .then(html => {
      this.bodyTarget.innerHTML = html
      this.hideLoading()
    })
    .catch(error => {
      console.error("Failed to load modal content:", error)
      this.bodyTarget.innerHTML = `
        <div class="text-center py-4">
          <div class="text-red-600 mb-2">
            <svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
            </svg>
          </div>
          <p class="text-gray-600">Failed to load content</p>
        </div>
      `
      this.hideLoading()
    })
  }

  showLoading() {
    this.bodyTarget.innerHTML = `
      <div class="flex items-center justify-center py-8">
        <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
        <span class="ml-2 text-gray-600">Loading...</span>
      </div>
    `
  }

  hideLoading() {
    // Loading state is replaced by content
  }

  // Update modal title dynamically
  updateTitle(title) {
    if (this.hasTitleTarget) {
      this.titleTarget.textContent = title
    }
  }

  // Update modal size dynamically
  updateSize(size) {
    this.sizeValue = size
    this.applySize()
  }

  // Enable/disable closable behavior
  toggleClosable(closable = true) {
    this.closableValue = closable
  }
}