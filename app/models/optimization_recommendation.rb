class OptimizationRecommendation < ApplicationRecord
  # Associations
  belongs_to :audit_report
  belongs_to :website

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true
  validates :priority, presence: true
  validates :status, presence: true
  validates :difficulty_level, inclusion: { in: %w[easy medium hard expert] }

  # Enums
  enum :priority, { low: 0, medium: 1, high: 2, critical: 3 }
  enum :status, { pending: 0, in_progress: 1, completed: 2, dismissed: 3 }

  # Scopes
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :actionable, -> { where(status: [ :pending, :in_progress ]) }
  scope :high_impact, -> { where(priority: [ :high, :critical ]) }
  scope :by_category, ->(category) { where(category: category) }

  # Methods
  def priority_color
    case priority
    when "critical" then "red"
    when "high" then "orange"
    when "medium" then "yellow"
    when "low" then "blue"
    else "gray"
    end
  end

  def difficulty_badge_color
    case difficulty_level
    when "easy" then "green"
    when "medium" then "yellow"
    when "hard" then "orange"
    when "expert" then "red"
    else "gray"
    end
  end

  def estimated_impact
    return "Unknown" unless potential_score_improvement

    if potential_score_improvement >= 10
      "High Impact (+#{potential_score_improvement} points)"
    elsif potential_score_improvement >= 5
      "Medium Impact (+#{potential_score_improvement} points)"
    else
      "Low Impact (+#{potential_score_improvement} points)"
    end
  end

  def can_implement_automatically?
    automated_fix_available? && difficulty_level == "easy"
  end

  def resources_list
    return [] unless resources.is_a?(Array)
    resources
  end

  def mark_as_completed!
    update!(status: :completed)
  end

  def mark_as_dismissed!(reason = nil)
    update!(status: :dismissed)
  end

  def mark_in_progress!
    update!(status: :in_progress)
  end

  # Class methods for generating recommendations
  def self.categories
    %w[
      images
      javascript
      css
      caching
      server_configuration
      third_party
      accessibility
      seo
      mobile
      security
    ]
  end

  def self.create_image_optimization_recommendation(audit_report, savings_estimate)
    create!(
      audit_report: audit_report,
      website: audit_report.website,
      title: "Optimize Images",
      description: "Compress and resize images to reduce page load time. Consider using modern formats like WebP.",
      category: "images",
      priority: :high,
      difficulty_level: "medium",
      estimated_savings: savings_estimate,
      potential_score_improvement: 15,
      implementation_guide: "1. Compress large images\n2. Use appropriate formats\n3. Implement lazy loading",
      resources: [
        "https://web.dev/optimize-images/",
        "https://developers.google.com/speed/pagespeed/insights/"
      ]
    )
  end

  def self.create_javascript_optimization_recommendation(audit_report, savings_estimate)
    create!(
      audit_report: audit_report,
      website: audit_report.website,
      title: "Optimize JavaScript Delivery",
      description: "Minimize, compress, and defer non-critical JavaScript to improve page load speed.",
      category: "javascript",
      priority: :high,
      difficulty_level: "hard",
      estimated_savings: savings_estimate,
      potential_score_improvement: 20,
      implementation_guide: "1. Minify JavaScript files\n2. Remove unused code\n3. Use async/defer attributes",
      resources: [
        "https://web.dev/reduce-unused-javascript/",
        "https://web.dev/efficiently-load-third-party-javascript/"
      ]
    )
  end
end
