class AuditReport < ApplicationRecord
  # Associations
  belongs_to :website
  belongs_to :triggered_by, class_name: 'User', optional: true
  has_many :performance_metrics, dependent: :destroy
  has_many :optimization_recommendations, dependent: :destroy

  # Validations
  validates :overall_score, numericality: { in: 0..100 }, allow_nil: true
  validates :audit_type, :status, presence: true

  # Enums
  enum :audit_type, { manual: 0, scheduled: 1, api_triggered: 2 }
  enum :status, { pending: 0, running: 1, completed: 2, failed: 3, cancelled: 4 }

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :successful, -> { completed.where.not(overall_score: nil) }
  scope :for_website, ->(website) { where(website: website) }

  # Broadcasts
  broadcasts_to ->(report) { [report.website.account, :audit_reports] } unless Rails.env.test?

  # Callbacks
  after_update_commit -> { broadcast_replace_to([website.account, :audit_reports]) } unless Rails.env.test?

  # Methods
  def performance_grade
    return 'N/A' unless overall_score

    case overall_score
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

  def duration_in_seconds
    return 0 unless started_at && completed_at
    (completed_at - started_at).to_f
  end

  def has_recommendations?
    optimization_recommendations.any?
  end

  def critical_recommendations
    optimization_recommendations.where(priority: :critical)
  end

  def high_priority_recommendations
    optimization_recommendations.where(priority: [:critical, :high])
  end

  def core_web_vitals
    performance_metrics.where(metric_type: %w[lcp fid cls])
  end

  def other_metrics
    performance_metrics.where.not(metric_type: %w[lcp fid cls])
  end

  def mark_as_running!
    update!(status: :running, started_at: Time.current, error_message: nil)
  end

  def mark_as_completed!(score: nil, results: {}, summary: {})
    update!(
      status: :completed,
      completed_at: Time.current,
      overall_score: score,
      raw_results: results,
      summary_data: summary,
      duration: duration_in_seconds
    )
  end

  def mark_as_failed!(error_message)
    update!(
      status: :failed,
      completed_at: Time.current,
      error_message: error_message,
      duration: duration_in_seconds
    )
  end
end
