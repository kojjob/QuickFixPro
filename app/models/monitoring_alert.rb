class MonitoringAlert < ApplicationRecord
  belongs_to :website

  # Since the schema uses string columns for alert_type and severity,
  # we need to handle them differently than integer enums
  ALERT_TYPES = {
    "performance_degradation" => 0,
    "availability_issue" => 1,
    "security_warning" => 2,
    "seo_issue" => 3,
    "accessibility_issue" => 4,
    "ssl_certificate_issue" => 5,
    "content_change" => 6
  }.freeze

  SEVERITIES = {
    "low" => 0,
    "medium" => 1,
    "high" => 2,
    "critical" => 3
  }.freeze

  # Validations
  validates :message, presence: true  # Using message instead of title based on schema
  validates :alert_type, presence: true, inclusion: { in: ALERT_TYPES.keys }
  validates :severity, presence: true, inclusion: { in: SEVERITIES.keys }

  # Override attribute accessors to work with the test expectations
  alias_attribute :title, :message

  # Scopes
  scope :active, -> { where(resolved: false) }
  scope :resolved, -> { where(resolved: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_severity, -> {
    # Order by severity priority (critical first)
    order(
      Arel.sql(
        "CASE severity
         WHEN 'critical' THEN 0
         WHEN 'high' THEN 1
         WHEN 'medium' THEN 2
         WHEN 'low' THEN 3
         ELSE 4
         END"
      )
    )
  }
  scope :critical_or_high, -> { where(severity: %w[critical high]) }

  # Methods to simulate enum behavior
  def self.alert_types
    ALERT_TYPES.keys
  end

  def self.severities
    SEVERITIES.keys
  end

  # Setter methods for enum-like behavior
  def alert_type=(value)
    super(value.to_s) if value
  end

  def severity=(value)
    super(value.to_s) if value
  end

  # Instance methods
  def resolve!
    update!(resolved: true, resolved_at: Time.current)
  end

  def severity_color
    case severity
    when "critical" then "red"
    when "high" then "orange"
    when "medium" then "yellow"
    when "low" then "blue"
    else "gray"
    end
  end

  def severity_badge_class
    case severity
    when "critical" then "bg-red-100 text-red-800"
    when "high" then "bg-orange-100 text-orange-800"
    when "medium" then "bg-yellow-100 text-yellow-800"
    when "low" then "bg-blue-100 text-blue-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  # Enum-like question methods
  ALERT_TYPES.keys.each do |type|
    define_method "#{type}?" do
      alert_type == type
    end
  end

  SEVERITIES.keys.each do |level|
    define_method "#{level}?" do
      severity == level
    end
  end
end
