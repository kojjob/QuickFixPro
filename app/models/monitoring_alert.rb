class MonitoringAlert < ApplicationRecord
  # Associations
  belongs_to :website
  
  # Validations
  validates :alert_type, presence: true
  validates :severity, presence: true
  validates :message, presence: true
  
  # Enums
  enum :alert_type, {
    performance_degradation: 0,
    site_down: 1,
    ssl_expiring: 2,
    response_time_spike: 3,
    error_rate_increase: 4
  }
  
  enum :severity, {
    low: 0,
    medium: 1,
    high: 2,
    critical: 3
  }
  
  # Scopes
  scope :unresolved, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_severity, -> { order(severity: :desc) }
  
  # Methods
  def resolve!
    update!(resolved: true, resolved_at: Time.current)
  end
end