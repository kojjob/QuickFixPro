import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Dashboard controller for auto-refresh and interactive features
export default class extends Controller {
  static targets = [
    "statsCard",
    "performanceChart",
    "activityFeed",
    "criticalIssues",
    "refreshIndicator",
    "lastUpdated",
    "timeRangeButton"
  ]
  
  static values = {
    refreshInterval: { type: Number, default: 30000 }, // 30 seconds
    autoRefresh: { type: Boolean, default: true },
    currentTimeRange: { type: String, default: "week" }
  }

  connect() {
    console.log("Dashboard controller connected")
    this.startAutoRefresh()
    this.updateLastRefreshedTime()
    
    // Add subtle animation when controller connects
    this.element.classList.add("dashboard-loaded")
    
    // Listen for Turbo events
    this.handleTurboEvents()
  }

  disconnect() {
    this.stopAutoRefresh()
  }

  // Manual refresh triggered by user
  async refresh(event) {
    event?.preventDefault()
    
    // Show loading state
    this.showRefreshIndicator()
    
    try {
      // Refresh stats cards
      await this.refreshStats()
      
      // Refresh activity feed
      await this.refreshActivityFeed()
      
      // Refresh performance chart
      await this.refreshPerformanceChart()
      
      // Update last refreshed time
      this.updateLastRefreshedTime()
      
      // Show success feedback
      this.showRefreshSuccess()
    } catch (error) {
      console.error("Dashboard refresh failed:", error)
      this.showRefreshError()
    } finally {
      this.hideRefreshIndicator()
    }
  }

  // Refresh stats cards using Turbo Frames
  async refreshStats() {
    if (!this.hasStatsCardTarget) return
    
    // Reload the stats turbo frame
    const statsFrame = document.getElementById("dashboard-stats")
    if (statsFrame) {
      await Turbo.visit(statsFrame.src, { 
        frame: "dashboard-stats",
        action: "replace" 
      })
    }
  }

  // Refresh activity feed
  async refreshActivityFeed() {
    if (!this.hasActivityFeedTarget) return
    
    const activityFrame = document.getElementById("activity-feed")
    if (activityFrame) {
      // Add loading state to activity feed
      this.activityFeedTarget.classList.add("opacity-50")
      
      await Turbo.visit(activityFrame.src, {
        frame: "activity-feed",
        action: "replace"
      })
      
      // Remove loading state
      this.activityFeedTarget.classList.remove("opacity-50")
      
      // Animate new items
      this.animateNewActivities()
    }
  }

  // Refresh performance chart
  async refreshPerformanceChart() {
    if (!this.hasPerformanceChartTarget) return
    
    const chartFrame = document.getElementById("performance-chart")
    if (chartFrame) {
      const url = new URL(chartFrame.src, window.location.origin)
      url.searchParams.set("range", this.currentTimeRangeValue)
      
      await Turbo.visit(url.toString(), {
        frame: "performance-chart",
        action: "replace"
      })
      
      // Re-animate chart bars
      this.animateChart()
    }
  }

  // Start auto-refresh timer
  startAutoRefresh() {
    if (!this.autoRefreshValue) return
    
    this.stopAutoRefresh() // Clear any existing interval
    
    this.refreshTimer = setInterval(() => {
      this.refresh()
    }, this.refreshIntervalValue)
    
    console.log(`Auto-refresh started (every ${this.refreshIntervalValue / 1000}s)`)
  }

  // Stop auto-refresh timer
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
      console.log("Auto-refresh stopped")
    }
  }

  // Toggle auto-refresh
  toggleAutoRefresh(event) {
    event?.preventDefault()
    
    this.autoRefreshValue = !this.autoRefreshValue
    
    if (this.autoRefreshValue) {
      this.startAutoRefresh()
      this.showNotification("Auto-refresh enabled", "success")
    } else {
      this.stopAutoRefresh()
      this.showNotification("Auto-refresh disabled", "info")
    }
    
    // Update toggle button state
    this.updateAutoRefreshButton()
  }

  // Change time range for performance chart
  changeTimeRange(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const range = button.dataset.range
    
    if (range === this.currentTimeRangeValue) return
    
    // Update active button styling
    this.timeRangeButtonTargets.forEach(btn => {
      btn.classList.remove("bg-blue-600", "text-white")
      btn.classList.add("text-gray-600", "hover:text-gray-900")
    })
    
    button.classList.remove("text-gray-600", "hover:text-gray-900")
    button.classList.add("bg-blue-600", "text-white")
    
    // Update current range
    this.currentTimeRangeValue = range
    
    // Refresh chart with new range
    this.refreshPerformanceChart()
  }

  // Animate new activity items
  animateNewActivities() {
    const activities = this.activityFeedTarget.querySelectorAll('[data-activity-item]')
    
    activities.forEach((item, index) => {
      if (!item.dataset.animated) {
        item.style.opacity = "0"
        item.style.transform = "translateY(-10px)"
        
        setTimeout(() => {
          item.style.transition = "all 0.3s ease-out"
          item.style.opacity = "1"
          item.style.transform = "translateY(0)"
          item.dataset.animated = "true"
        }, index * 50)
      }
    })
  }

  // Animate chart bars
  animateChart() {
    if (!this.hasPerformanceChartTarget) return
    
    const bars = this.performanceChartTarget.querySelectorAll('[data-chart-bar]')
    
    bars.forEach((bar, index) => {
      const originalHeight = bar.style.height
      bar.style.height = "0"
      bar.style.transition = "none"
      
      setTimeout(() => {
        bar.style.transition = "height 0.5s ease-out"
        bar.style.height = originalHeight
      }, index * 30)
    })
  }

  // Show refresh indicator
  showRefreshIndicator() {
    if (this.hasRefreshIndicatorTarget) {
      this.refreshIndicatorTarget.classList.remove("hidden")
      this.refreshIndicatorTarget.classList.add("animate-spin")
    }
  }

  // Hide refresh indicator
  hideRefreshIndicator() {
    if (this.hasRefreshIndicatorTarget) {
      this.refreshIndicatorTarget.classList.add("hidden")
      this.refreshIndicatorTarget.classList.remove("animate-spin")
    }
  }

  // Update last refreshed time
  updateLastRefreshedTime() {
    if (this.hasLastUpdatedTarget) {
      const now = new Date()
      const timeString = now.toLocaleTimeString('en-US', { 
        hour: '2-digit', 
        minute: '2-digit' 
      })
      this.lastUpdatedTarget.textContent = `Last updated: ${timeString}`
    }
  }

  // Show notification
  showNotification(message, type = "info") {
    // Create notification element
    const notification = document.createElement("div")
    notification.className = `fixed top-4 right-4 px-4 py-3 rounded-lg shadow-lg transform transition-all duration-300 translate-x-full z-50`
    
    // Add type-specific styling
    const styles = {
      success: "bg-green-500 text-white",
      error: "bg-red-500 text-white",
      info: "bg-blue-500 text-white",
      warning: "bg-yellow-500 text-white"
    }
    
    notification.classList.add(...styles[type].split(" "))
    notification.innerHTML = `
      <div class="flex items-center space-x-2">
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.classList.remove("translate-x-full")
      notification.classList.add("translate-x-0")
    }, 10)
    
    // Auto remove after 3 seconds
    setTimeout(() => {
      notification.classList.remove("translate-x-0")
      notification.classList.add("translate-x-full")
      
      setTimeout(() => {
        notification.remove()
      }, 300)
    }, 3000)
  }

  // Show refresh success
  showRefreshSuccess() {
    this.showNotification("Dashboard refreshed successfully", "success")
  }

  // Show refresh error
  showRefreshError() {
    this.showNotification("Failed to refresh dashboard", "error")
  }

  // Update auto-refresh button state
  updateAutoRefreshButton() {
    const button = this.element.querySelector('[data-auto-refresh-toggle]')
    if (!button) return
    
    if (this.autoRefreshValue) {
      button.textContent = "Auto-refresh: ON"
      button.classList.remove("bg-gray-200", "text-gray-700")
      button.classList.add("bg-green-100", "text-green-700")
    } else {
      button.textContent = "Auto-refresh: OFF"
      button.classList.remove("bg-green-100", "text-green-700")
      button.classList.add("bg-gray-200", "text-gray-700")
    }
  }

  // Handle Turbo events
  handleTurboEvents() {
    // Re-animate after Turbo frame updates
    document.addEventListener("turbo:frame-load", (event) => {
      if (event.target.id === "performance-chart") {
        this.animateChart()
      } else if (event.target.id === "activity-feed") {
        this.animateNewActivities()
      }
    })
    
    // Handle Turbo Stream updates
    document.addEventListener("turbo:before-stream-render", (event) => {
      // Add any pre-render logic here
    })
  }

  // Pause auto-refresh when page is hidden
  handleVisibilityChange() {
    if (document.hidden) {
      this.wasAutoRefreshing = this.autoRefreshValue
      this.stopAutoRefresh()
    } else if (this.wasAutoRefreshing) {
      this.startAutoRefresh()
      this.refresh() // Refresh immediately when page becomes visible
    }
  }
}