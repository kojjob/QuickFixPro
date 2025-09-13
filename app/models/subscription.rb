class Subscription < ApplicationRecord
  # Associations
  belongs_to :account
  has_many :payments, dependent: :destroy

  # Validations
  validates :plan_name, presence: true, inclusion: { in: %w[starter professional enterprise] }
  validates :status, presence: true
  validates :monthly_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Enums
  enum :status, { trial: 0, active: 1, past_due: 2, cancelled: 3, expired: 4 }, prefix: :subscription

  # Constants for plan limits
  PLAN_LIMITS = {
    'starter' => {
      websites: 5,
      monthly_audits: 100,
      users: 2,
      api_requests: 1000,
      historical_data_months: 3,
      support_level: 'email'
    },
    'professional' => {
      websites: 25,
      monthly_audits: 500,
      users: 10,
      api_requests: 10000,
      historical_data_months: 12,
      support_level: 'priority'
    },
    'enterprise' => {
      websites: -1, # unlimited
      monthly_audits: -1, # unlimited
      users: -1, # unlimited
      api_requests: -1, # unlimited
      historical_data_months: -1, # unlimited
      support_level: 'dedicated'
    }
  }.freeze

  PLAN_PRICES = {
    'starter' => 29.00,
    'professional' => 99.00,
    'enterprise' => 299.00
  }.freeze

  # Scopes
  scope :active, -> { where(status: [:trial, :active]) }
  scope :billable, -> { where(status: :active) }
  scope :by_plan, ->(plan) { where(plan_name: plan) }

  # Callbacks
  before_validation :set_plan_defaults, if: :plan_name_changed?
  before_create :set_trial_period

  # Methods
  def plan_limits
    (PLAN_LIMITS[plan_name] || {}).with_indifferent_access
  end

  def usage_limit_for(feature)
    limit = plan_limits[feature.to_s]
    return Float::INFINITY if limit == -1
    limit || 0
  end

  def current_usage_for(feature)
    current_usage[feature.to_s] || 0
  end

  def usage_percentage_for(feature)
    return 0 unless plan_limits[feature.to_s]
    
    limit = usage_limit_for(feature)
    return 0 if limit == Float::INFINITY
    
    usage = current_usage_for(feature)
    return 0 if limit == 0
    
    ((usage.to_f / limit) * 100).round(1)
  end

  def within_limit?(feature, additional_usage = 0)
    limit = usage_limit_for(feature)
    return true if limit == Float::INFINITY
    
    total_usage = current_usage_for(feature) + additional_usage
    total_usage <= limit
  end

  def increment_usage!(feature, amount = 1)
    feature_str = feature.to_s
    self.current_usage = current_usage.dup
    self.current_usage[feature_str] = current_usage_for(feature) + amount
    save!
  end

  def reset_usage!
    update!(current_usage: {}, billing_cycle_started_at: Time.current)
  end

  def trial_active?
    subscription_trial? && trial_ends_at.present? && trial_ends_at > Time.current
  end

  def trial_expired?
    subscription_trial? && trial_ends_at.present? && trial_ends_at <= Time.current
  end

  def days_until_trial_expires
    return 0 unless trial_active?
    ((trial_ends_at - Time.current) / 1.day).ceil
  end

  def can_upgrade_to?(new_plan)
    return false unless %w[starter professional enterprise].include?(new_plan)
    return false if new_plan == plan_name
    
    plan_hierarchy = { 'starter' => 1, 'professional' => 2, 'enterprise' => 3 }
    plan_hierarchy[new_plan] > plan_hierarchy[plan_name]
  end

  def upgrade_to!(new_plan)
    return false unless can_upgrade_to?(new_plan)
    
    self.plan_name = new_plan
    set_plan_defaults
    save!
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end

  def reactivate!
    return false if cancelled_at.blank?
    
    update!(
      status: :active,
      cancelled_at: nil,
      billing_cycle_started_at: Time.current
    )
  end

  private

  def set_plan_defaults
    self.usage_limits = PLAN_LIMITS[plan_name] || {}
    self.monthly_price = PLAN_PRICES[plan_name] || 0
    self.plan_features = generate_plan_features
  end

  def set_trial_period
    return unless subscription_trial?
    self.trial_ends_at = 14.days.from_now unless trial_ends_at.present?
  end

  def generate_plan_features
    features = {
      'real_time_monitoring' => true,
      'performance_alerts' => true,
      'basic_recommendations' => true
    }

    case plan_name
    when 'professional'
      features.merge!({
        'advanced_recommendations' => true,
        'api_access' => true,
        'custom_alerts' => true,
        'white_label' => false
      })
    when 'enterprise'
      features.merge!({
        'advanced_recommendations' => true,
        'api_access' => true,
        'custom_alerts' => true,
        'white_label' => true,
        'dedicated_support' => true,
        'custom_integrations' => true
      })
    end

    features
  end
end
