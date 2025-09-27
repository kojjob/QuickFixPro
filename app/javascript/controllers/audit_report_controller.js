import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="audit-report"
export default class extends Controller {
  static targets = [
    "score", "recommendation", "exportMenu", "shareMenu",
    "metric", "tabButton", "tabPanel", "filterButton"
  ]

  static values = {
    reportId: Number,
    refreshInterval: { type: Number, default: 5000 }
  }

  connect() {
    console.log("Audit report controller connected")
    this.animateScores()
    this.startAutoRefreshIfNeeded()
    this.initializeTooltips()
  }

  disconnect() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  // Animate score counting up
  animateScores() {
    this.scoreTargets.forEach(element => {
      const target = parseInt(element.dataset.target)
      const duration = 1500
      const start = 0
      const increment = target / (duration / 16)
      let current = start

      const timer = setInterval(() => {
        current += increment
        if (current >= target) {
          current = target
          clearInterval(timer)
        }
        element.textContent = Math.round(current)
      }, 16)
    })
  }

  // Toggle recommendation details
  toggleRecommendation(event) {
    const button = event.currentTarget
    const recommendationId = button.dataset.recommendationId
    const detail = this.element.querySelector(`#recommendation-detail-${recommendationId}`)
    const icon = button.querySelector('.chevron-icon')

    if (detail.classList.contains('hidden')) {
      detail.classList.remove('hidden')
      detail.classList.add('animate-slide-down')
      icon.style.transform = 'rotate(180deg)'
    } else {
      detail.classList.add('hidden')
      detail.classList.remove('animate-slide-down')
      icon.style.transform = 'rotate(0deg)'
    }
  }

  // Mark recommendation as done
  async markAsDone(event) {
    const button = event.currentTarget
    const recommendationId = button.dataset.recommendationId

    button.disabled = true
    button.innerHTML = '<svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>'

    try {
      const response = await fetch(`/audit_reports/${this.reportIdValue}/recommendations/${recommendationId}/mark_done`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const card = button.closest('.recommendation-card')
        card.classList.add('opacity-50', 'line-through')
        button.classList.add('hidden')

        // Show success notification
        this.showNotification('Recommendation marked as complete!', 'success')
      } else {
        throw new Error('Failed to mark as done')
      }
    } catch (error) {
      console.error('Error:', error)
      button.disabled = false
      button.innerHTML = 'Mark as Done'
      this.showNotification('Failed to update recommendation', 'error')
    }
  }

  // Toggle export menu
  toggleExportMenu() {
    this.exportMenuTarget.classList.toggle('hidden')
    if (this.shareMenuTarget && !this.shareMenuTarget.classList.contains('hidden')) {
      this.shareMenuTarget.classList.add('hidden')
    }
  }

  // Toggle share menu
  toggleShareMenu() {
    this.shareMenuTarget.classList.toggle('hidden')
    if (this.exportMenuTarget && !this.exportMenuTarget.classList.contains('hidden')) {
      this.exportMenuTarget.classList.add('hidden')
    }
  }

  // Export report
  async exportReport(event) {
    const format = event.currentTarget.dataset.format

    try {
      const response = await fetch(`/audit_reports/${this.reportIdValue}/export.${format}`)

      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `audit-report-${this.reportIdValue}.${format}`
        document.body.appendChild(a)
        a.click()
        window.URL.revokeObjectURL(url)
        a.remove()

        this.exportMenuTarget.classList.add('hidden')
        this.showNotification(`Report exported as ${format.toUpperCase()}`, 'success')
      }
    } catch (error) {
      console.error('Export error:', error)
      this.showNotification('Failed to export report', 'error')
    }
  }

  // Share report
  async shareReport(event) {
    const method = event.currentTarget.dataset.method
    const url = window.location.href
    const title = 'Audit Report'
    const text = `Check out this website audit report: ${this.element.querySelector('h1').textContent}`

    switch(method) {
      case 'copy':
        await navigator.clipboard.writeText(url)
        this.showNotification('Link copied to clipboard!', 'success')
        break
      case 'email':
        window.location.href = `mailto:?subject=${encodeURIComponent(title)}&body=${encodeURIComponent(text + '\n\n' + url)}`
        break
      case 'share':
        if (navigator.share) {
          await navigator.share({ title, text, url })
        } else {
          await navigator.clipboard.writeText(url)
          this.showNotification('Link copied to clipboard!', 'success')
        }
        break
    }

    this.shareMenuTarget.classList.add('hidden')
  }

  // Switch tabs
  switchTab(event) {
    const button = event.currentTarget
    const tabName = button.dataset.tab

    // Update button states
    this.tabButtonTargets.forEach(btn => {
      if (btn.dataset.tab === tabName) {
        btn.classList.add('border-indigo-500', 'text-indigo-600', 'bg-indigo-50')
        btn.classList.remove('border-transparent', 'text-gray-500', 'hover:text-gray-700')
      } else {
        btn.classList.remove('border-indigo-500', 'text-indigo-600', 'bg-indigo-50')
        btn.classList.add('border-transparent', 'text-gray-500', 'hover:text-gray-700')
      }
    })

    // Update panel visibility
    this.tabPanelTargets.forEach(panel => {
      if (panel.dataset.tab === tabName) {
        panel.classList.remove('hidden')
        panel.classList.add('animate-fade-in')
      } else {
        panel.classList.add('hidden')
        panel.classList.remove('animate-fade-in')
      }
    })
  }

  // Filter recommendations
  filterRecommendations(event) {
    const button = event.currentTarget
    const priority = button.dataset.priority

    // Update button states
    this.filterButtonTargets.forEach(btn => {
      if (btn.dataset.priority === priority) {
        btn.classList.add('bg-indigo-600', 'text-white')
        btn.classList.remove('bg-white', 'text-gray-700')
      } else {
        btn.classList.remove('bg-indigo-600', 'text-white')
        btn.classList.add('bg-white', 'text-gray-700')
      }
    })

    // Filter recommendation cards
    const cards = this.element.querySelectorAll('.recommendation-card')
    cards.forEach(card => {
      if (priority === 'all' || card.dataset.priority === priority) {
        card.classList.remove('hidden')
        card.classList.add('animate-fade-in')
      } else {
        card.classList.add('hidden')
        card.classList.remove('animate-fade-in')
      }
    })
  }

  // Auto-refresh for in-progress audits
  startAutoRefreshIfNeeded() {
    const status = this.element.dataset.status

    if (status === 'in_progress') {
      this.refreshTimer = setInterval(() => {
        this.refreshReport()
      }, this.refreshIntervalValue)
    }
  }

  async refreshReport() {
    try {
      const response = await fetch(`/audit_reports/${this.reportIdValue}.json`, {
        headers: {
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        const data = await response.json()

        if (data.status === 'completed') {
          clearInterval(this.refreshTimer)
          // Reload the page to show completed state
          window.location.reload()
        } else {
          // Update progress indicators
          this.updateProgress(data.progress)
        }
      }
    } catch (error) {
      console.error('Refresh error:', error)
    }
  }

  updateProgress(progress) {
    const progressBar = this.element.querySelector('.progress-bar')
    if (progressBar) {
      progressBar.style.width = `${progress}%`
      progressBar.textContent = `${progress}%`
    }
  }

  // Initialize tooltips
  initializeTooltips() {
    const tooltips = this.element.querySelectorAll('[data-tooltip]')

    tooltips.forEach(element => {
      element.addEventListener('mouseenter', (e) => {
        const tooltip = document.createElement('div')
        tooltip.className = 'absolute z-50 px-3 py-2 text-sm text-white bg-gray-900 rounded-lg shadow-lg'
        tooltip.textContent = e.target.dataset.tooltip

        document.body.appendChild(tooltip)

        const rect = e.target.getBoundingClientRect()
        tooltip.style.left = `${rect.left + rect.width / 2 - tooltip.offsetWidth / 2}px`
        tooltip.style.top = `${rect.top - tooltip.offsetHeight - 8}px`

        e.target._tooltip = tooltip
      })

      element.addEventListener('mouseleave', (e) => {
        if (e.target._tooltip) {
          e.target._tooltip.remove()
          delete e.target._tooltip
        }
      })
    })
  }

  // Show notification
  showNotification(message, type = 'info') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-6 py-4 rounded-lg shadow-lg text-white animate-slide-in ${
      type === 'success' ? 'bg-green-600' :
      type === 'error' ? 'bg-red-600' :
      'bg-blue-600'
    }`
    notification.innerHTML = `
      <div class="flex items-center space-x-3">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          ${type === 'success' ?
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
            type === 'error' ?
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>' :
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
          }
        </svg>
        <span>${message}</span>
      </div>
    `

    document.body.appendChild(notification)

    setTimeout(() => {
      notification.classList.add('animate-slide-out')
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
}