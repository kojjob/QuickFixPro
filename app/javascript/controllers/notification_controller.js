import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    type: String,
    autoDismiss: { type: Boolean, default: true },
    duration: { type: Number, default: 5000 }
  }

  connect() {
    this.show()
    
    if (this.autoDismissValue) {
      this.timeout = setTimeout(() => {
        this.dismiss()
      }, this.durationValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  show() {
    // Slide in animation
    requestAnimationFrame(() => {
      this.element.classList.remove('translate-x-full', 'opacity-0')
      this.element.classList.add('translate-x-0', 'opacity-100')
    })
  }

  dismiss() {
    // Clear timeout if exists
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    // Slide out animation
    this.element.classList.remove('translate-x-0', 'opacity-100')
    this.element.classList.add('translate-x-full', 'opacity-0')

    // Remove from DOM after animation
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  // Static method to create notifications dynamically
  static create(type, message, options = {}) {
    const container = document.getElementById('notifications')
    if (!container) return

    const notification = document.createElement('div')
    const id = `notification-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
    
    notification.id = id
    notification.className = 'notification-toast max-w-sm w-full transform transition-all duration-300 translate-x-full opacity-0 mb-2'
    notification.setAttribute('data-controller', 'notification')
    notification.setAttribute('data-notification-type-value', type)
    notification.setAttribute('data-notification-auto-dismiss-value', options.autoDismiss !== false)
    notification.setAttribute('data-notification-duration-value', options.duration || 5000)

    // Set colors based on type
    const typeClasses = {
      success: {
        bg: 'bg-green-50',
        border: 'border-green-200',
        text: 'text-green-800',
        icon: 'text-green-400',
        path: 'M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
      },
      error: {
        bg: 'bg-red-50',
        border: 'border-red-200',
        text: 'text-red-800',
        icon: 'text-red-400',
        path: 'M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z'
      },
      warning: {
        bg: 'bg-yellow-50',
        border: 'border-yellow-200',
        text: 'text-yellow-800',
        icon: 'text-yellow-400',
        path: 'M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z'
      },
      info: {
        bg: 'bg-blue-50',
        border: 'border-blue-200',
        text: 'text-blue-800',
        icon: 'text-blue-400',
        path: 'M11.25 11.25l.041-.02a.75.75 0 011.063.852l-.708 2.836a.75.75 0 001.063.853L15.75 12M6 12a9 9 0 1118 0 9 9 0 01-18 0z'
      }
    }

    const classes = typeClasses[type] || typeClasses.info

    notification.innerHTML = `
      <div class="${classes.bg} ${classes.border} border rounded-lg shadow-lg p-4">
        <div class="flex items-start">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 ${classes.icon}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="${classes.path}" />
            </svg>
          </div>
          
          <div class="ml-3 flex-1">
            <p class="text-sm font-medium ${classes.text}">
              ${message}
            </p>
          </div>
          
          ${options.dismissible !== false ? `
            <div class="ml-4 flex-shrink-0 flex">
              <button
                type="button"
                class="inline-flex ${classes.text} hover:opacity-75 focus:outline-none focus:opacity-75"
                data-action="notification#dismiss"
              >
                <span class="sr-only">Close</span>
                <svg class="h-4 w-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          ` : ''}
        </div>
      </div>
    `

    container.appendChild(notification)
    return notification
  }
}