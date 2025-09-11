class PerformanceMetric < ApplicationRecord
  # Associations
  belongs_to :audit_report
  belongs_to :website

  # Validations
  validates :metric_type, presence: true, inclusion: { 
    in: %w[lcp fid cls ttfb fcp speed_index total_blocking_time],
    message: "must be a valid metric type"
  }
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :threshold_status, presence: true

  # Enums
  enum :threshold_status, { good: 0, needs_improvement: 1, poor: 2 }

  # Constants for Core Web Vitals thresholds (in milliseconds)
  THRESHOLDS = {
    'lcp' => { good: 2500, poor: 4000, unit: 'ms', name: 'Largest Contentful Paint' },
    'fid' => { good: 100, poor: 300, unit: 'ms', name: 'First Input Delay' },
    'cls' => { good: 0.1, poor: 0.25, unit: 'score', name: 'Cumulative Layout Shift' },
    'ttfb' => { good: 800, poor: 1800, unit: 'ms', name: 'Time to First Byte' },
    'fcp' => { good: 1800, poor: 3000, unit: 'ms', name: 'First Contentful Paint' },
    'speed_index' => { good: 3400, poor: 5800, unit: 'ms', name: 'Speed Index' },
    'total_blocking_time' => { good: 200, poor: 600, unit: 'ms', name: 'Total Blocking Time' }
  }.freeze

  # Scopes
  scope :core_web_vitals, -> { where(metric_type: %w[lcp fid cls]) }
  scope :by_type, ->(type) { where(metric_type: type) }
  scope :poor_performance, -> { where(threshold_status: :poor) }
  scope :good_performance, -> { where(threshold_status: :good) }

  # Callbacks
  before_save :calculate_threshold_status
  before_save :set_thresholds

  # Methods
  def metric_value
    value
  end

  def metric_value=(val)
    self.value = val
  end

  def display_name
    THRESHOLDS.dig(metric_type, :name) || metric_type.humanize
  end

  def display_value
    case unit
    when 'ms'
      "#{value.to_i}ms"
    when 'score'
      value.round(3).to_s
    else
      "#{value} #{unit}"
    end
  end

  def is_core_web_vital?
    %w[lcp fid cls].include?(metric_type)
  end

  def threshold_color
    case threshold_status
    when 'good' then 'green'
    when 'needs_improvement' then 'yellow'  
    when 'poor' then 'red'
    else 'gray'
    end
  end

  def score_impact
    case threshold_status
    when 'good' then score_contribution || 10
    when 'needs_improvement' then (score_contribution || 10) * 0.7
    when 'poor' then (score_contribution || 10) * 0.3
    else 0
    end
  end

  private

  def calculate_threshold_status
    return unless THRESHOLDS[metric_type]

    thresholds = THRESHOLDS[metric_type]
    self.threshold_status = if value <= thresholds[:good]
                             :good
                           elsif value <= thresholds[:poor]
                             :needs_improvement
                           else
                             :poor
                           end
  end

  def set_thresholds
    return unless THRESHOLDS[metric_type]

    thresholds = THRESHOLDS[metric_type]
    self.threshold_good = thresholds[:good]
    self.threshold_poor = thresholds[:poor]
    self.unit = thresholds[:unit]
  end
end
