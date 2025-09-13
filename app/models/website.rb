class Website < ApplicationRecord
  include AccountOwnable

  # Associations
  belongs_to :created_by, class_name: 'User'
  has_many :audit_reports, dependent: :destroy
  has_many :performance_metrics, through: :audit_reports
  has_many :optimization_recommendations, through: :audit_reports
  has_many :monitoring_alerts, dependent: :destroy

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }
  validates :url, uniqueness: { scope: :account_id, message: "is already being monitored in this account" }

  # Enums
  enum :status, { active: 0, paused: 1, archived: 2 }, default: :active
  enum :monitoring_frequency, { manual: 0, daily: 1, weekly: 2, monthly: 3 }

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :recent, -> { order(created_at: :desc) }
  scope :publicly_visible, -> { where(public_showcase: true) }
  scope :active_monitoring, -> { where(status: :active, monitoring_frequency: [:daily, :weekly, :monthly]) }
  scope :due_for_monitoring, -> { active_monitoring.where(last_monitored_at: nil).or(
    active_monitoring.where('last_monitored_at < ?', 1.day.ago)
  )}
  scope :by_score_range, ->(min, max = 100) { where(current_score: min..max) }

  # Broadcasts
  broadcasts_to ->(website) { [website.account, :websites] }

  # Callbacks
  before_validation :normalize_url
  after_create_commit -> { broadcast_append_to([account, :websites], target: "websites") } unless Rails.env.test?
  after_update_commit -> { broadcast_replace_to([account, :websites]) } unless Rails.env.test?
  after_destroy_commit -> { broadcast_remove_to([account, :websites]) } unless Rails.env.test?

  # Methods
  def display_url
    parsed_uri = URI.parse(url)
    parsed_uri.host || url
  rescue URI::InvalidURIError
    url
  end

  def performance_grade
    return 'N/A' unless current_score

    case current_score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end

  def performance_color
    case performance_grade
    when 'A', 'B' then 'green'
    when 'C' then 'yellow'
    when 'D', 'F' then 'red'
    else 'gray'
    end
  end

  def should_monitor?
    active? && !manual? && (last_monitored_at.nil? || monitoring_overdue?)
  end

  def monitoring_overdue?
    return false unless last_monitored_at

    case monitoring_frequency
    when 'daily'
      last_monitored_at < 1.day.ago
    when 'weekly'  
      last_monitored_at < 1.week.ago
    when 'monthly'
      last_monitored_at < 1.month.ago
    else
      false
    end
  end

  def latest_audit_report
    audit_reports.order(created_at: :desc).first
  end

  def audit_history_data(limit: 30)
    audit_reports
      .where('created_at > ?', limit.days.ago)
      .order(:created_at)
      .pluck(:created_at, :overall_score)
      .map { |date, score| { x: date, y: score } }
  end

  def update_current_score!(score)
    update!(current_score: score, last_monitored_at: Time.current)
  end

  private

  def normalize_url
    return unless url.present?
    
    self.url = url.strip
    unless url.match?(/^https?:\/\//)
      self.url = "https://#{url}"
    end
  end
end
