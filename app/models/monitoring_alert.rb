class MonitoringAlert < ApplicationRecord
  # Associations
  belongs_to :website

  # Enums
  enum :alert_type, {
    performance_degradation: 'performance_degradation',
    security_issue: 'security_issue',
    seo_problem: 'seo_problem',
    accessibility_violation: 'accessibility_violation',
    uptime_issue: 'uptime_issue',
    ssl_expiry: 'ssl_expiry',
    broken_link: 'broken_link',
    high_response_time: 'high_response_time'
  }, prefix: true

  enum :severity, {
    low: 'low',
    medium: 'medium', 
    high: 'high',
    critical: 'critical'
  }, prefix: true

  # Validations
  validates :alert_type, presence: true
  validates :severity, presence: true
  validates :message, presence: true

  # Scopes
  scope :active, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical_alerts, -> { where(severity: :critical) }
  scope :unresolved_critical, -> { active.critical_alerts }

  # Methods
  def resolve!(resolved_by = nil)
    update!(
      resolved: true,
      resolved_at: Time.current,
      metadata: metadata.merge(resolved_by: resolved_by&.id)
    )
  end

  def severity_color
    case severity
    when 'low' then 'green'
    when 'medium' then 'yellow' 
    when 'high' then 'orange'
    when 'critical' then 'red'
    else 'gray'
    end
  end

  def severity_icon
    case severity
    when 'low' then 'information-circle'
    when 'medium' then 'exclamation'
    when 'high' then 'exclamation-triangle'
    when 'critical' then 'x-circle'
    else 'question-mark-circle'
    end
  end

  def alert_type_icon
    case alert_type
    when 'performance_degradation' then 'clock'
    when 'security_issue' then 'shield-exclamation'
    when 'seo_problem' then 'search-circle'
    when 'accessibility_violation' then 'user-group'
    when 'uptime_issue' then 'server'
    when 'ssl_expiry' then 'lock-open'
    when 'broken_link' then 'link'
    when 'high_response_time' then 'clock'
    else 'bell'
    end
  end

  def time_since_created
    distance_of_time_in_words = ActionController::Base.helpers.distance_of_time_in_words(created_at, Time.current)
    "#{distance_of_time_in_words} ago"
  end
end
