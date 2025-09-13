import { Controller } from "@hotwired/stimulus"

// Premium Chart Controller with animations and dark mode support
export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    type: String,
    data: Object,
    options: Object,
    animated: { type: Boolean, default: true },
    gradient: { type: Boolean, default: true }
  }

  connect() {
    this.initializeChart()
    this.setupResponsiveResize()
    this.observeThemeChanges()
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    if (this.themeObserver) {
      this.themeObserver.disconnect()
    }
  }

  initializeChart() {
    if (!window.Chart) {
      console.error("Chart.js is not loaded")
      return
    }

    const ctx = this.canvasTarget.getContext("2d")

    // Apply gradient if enabled
    if (this.gradientValue) {
      this.applyGradients(ctx)
    }

    // Enhanced options with animations
    const enhancedOptions = {
      ...this.optionsValue,
      responsive: true,
      maintainAspectRatio: false,
      animation: this.animatedValue ? {
        duration: 1500,
        easing: 'easeInOutQuart',
        delay: (context) => {
          let delay = 0
          if (context.type === 'data' && context.mode === 'default') {
            delay = context.dataIndex * 50 + context.datasetIndex * 100
          }
          return delay
        },
        onComplete: () => {
          this.dispatch("animated", { detail: { chart: this.chart } })
        }
      } : false,
      interaction: {
        mode: 'nearest',
        axis: 'x',
        intersect: false
      },
      plugins: {
        ...this.optionsValue?.plugins,
        tooltip: {
          ...this.optionsValue?.plugins?.tooltip,
          backgroundColor: 'rgba(17, 24, 39, 0.9)',
          titleColor: '#fff',
          bodyColor: '#fff',
          borderColor: 'rgba(99, 102, 241, 0.5)',
          borderWidth: 1,
          padding: 12,
          cornerRadius: 8,
          displayColors: true,
          callbacks: {
            ...this.optionsValue?.plugins?.tooltip?.callbacks,
            label: (context) => {
              let label = context.dataset.label || ''
              if (label) {
                label += ': '
              }
              if (context.parsed.y !== null) {
                label += new Intl.NumberFormat('en-US', {
                  minimumFractionDigits: 0,
                  maximumFractionDigits: 2
                }).format(context.parsed.y)
              }
              return label
            }
          }
        },
        legend: {
          ...this.optionsValue?.plugins?.legend,
          labels: {
            ...this.optionsValue?.plugins?.legend?.labels,
            padding: 20,
            usePointStyle: true,
            font: {
              size: 12,
              weight: '500'
            }
          }
        }
      }
    }

    this.chart = new Chart(ctx, {
      type: this.typeValue,
      data: this.enhancedData,
      options: enhancedOptions
    })
  }

  get enhancedData() {
    const data = { ...this.dataValue }

    // Add hover animations to datasets
    if (data.datasets) {
      data.datasets = data.datasets.map((dataset, index) => ({
        ...dataset,
        borderWidth: dataset.borderWidth || 2,
        tension: dataset.tension || 0.4,
        hoverBorderWidth: (dataset.borderWidth || 2) + 1,
        hoverBackgroundColor: dataset.hoverBackgroundColor || this.adjustAlpha(dataset.backgroundColor || this.getDefaultColor(index), 0.8)
      }))
    }

    return data
  }

  applyGradients(ctx) {
    if (!this.dataValue.datasets) return

    this.dataValue.datasets = this.dataValue.datasets.map((dataset, index) => {
      if (dataset.backgroundColor && typeof dataset.backgroundColor === 'string') {
        const gradient = this.createGradient(ctx, dataset.backgroundColor, index)
        return {
          ...dataset,
          backgroundColor: gradient,
          borderColor: dataset.borderColor || dataset.backgroundColor
        }
      }
      return dataset
    })
  }

  createGradient(ctx, color, index) {
    const gradient = ctx.createLinearGradient(0, 0, 0, 400)
    const baseColors = [
      ['rgba(99, 102, 241, 0.8)', 'rgba(99, 102, 241, 0.1)'],   // Indigo
      ['rgba(16, 185, 129, 0.8)', 'rgba(16, 185, 129, 0.1)'],  // Green
      ['rgba(245, 158, 11, 0.8)', 'rgba(245, 158, 11, 0.1)'],   // Amber
      ['rgba(239, 68, 68, 0.8)', 'rgba(239, 68, 68, 0.1)'],     // Red
      ['rgba(139, 92, 246, 0.8)', 'rgba(139, 92, 246, 0.1)']    // Purple
    ]

    const colors = baseColors[index % baseColors.length]
    gradient.addColorStop(0, colors[0])
    gradient.addColorStop(1, colors[1])

    return gradient
  }

  setupResponsiveResize() {
    this.resizeObserver = new ResizeObserver(() => {
      if (this.chart) {
        this.chart.resize()
      }
    })

    this.resizeObserver.observe(this.element)
  }

  observeThemeChanges() {
    // Watch for dark mode changes
    this.themeObserver = new MutationObserver(() => {
      this.updateChartTheme()
    })

    this.themeObserver.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ['class', 'data-theme']
    })
  }

  updateChartTheme() {
    if (!this.chart) return

    const isDark = document.documentElement.classList.contains('dark')
    const textColor = isDark ? '#e5e7eb' : '#374151'
    const gridColor = isDark ? 'rgba(156, 163, 175, 0.1)' : 'rgba(156, 163, 175, 0.2)'

    this.chart.options.scales = {
      ...this.chart.options.scales,
      x: {
        ...this.chart.options.scales?.x,
        ticks: {
          ...this.chart.options.scales?.x?.ticks,
          color: textColor
        },
        grid: {
          ...this.chart.options.scales?.x?.grid,
          color: gridColor
        }
      },
      y: {
        ...this.chart.options.scales?.y,
        ticks: {
          ...this.chart.options.scales?.y?.ticks,
          color: textColor
        },
        grid: {
          ...this.chart.options.scales?.y?.grid,
          color: gridColor
        }
      }
    }

    this.chart.options.plugins.legend.labels.color = textColor
    this.chart.update()
  }

  updateData(newData) {
    if (!this.chart) return

    this.chart.data = newData
    this.chart.update('active')
  }

  getDefaultColor(index) {
    const colors = [
      'rgba(99, 102, 241, 0.6)',   // Indigo
      'rgba(16, 185, 129, 0.6)',   // Green
      'rgba(245, 158, 11, 0.6)',   // Amber
      'rgba(239, 68, 68, 0.6)',    // Red
      'rgba(139, 92, 246, 0.6)'    // Purple
    ]
    return colors[index % colors.length]
  }

  adjustAlpha(color, alpha) {
    const match = color.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*[\d.]+)?\)/)
    if (match) {
      return `rgba(${match[1]}, ${match[2]}, ${match[3]}, ${alpha})`
    }
    return color
  }
}