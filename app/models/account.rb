class Account < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_many :websites, dependent: :destroy
  has_many :subscriptions, dependent: :destroy
  has_many :audit_reports, through: :websites
  belongs_to :created_by, class_name: 'User', optional: true

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :subdomain, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" },
            length: { in: 3..63 }

  # Enums
  enum :status, { trial: 0, active: 1, suspended: 2, cancelled: 3 }

  # Scopes
  scope :active_accounts, -> { where(status: [:trial, :active]) }

  # Methods
  def display_name
    name.presence || subdomain.humanize
  end

  def trial_expired?
    trial? && created_at < 14.days.ago
  end

  def current_subscription
    subscriptions.active.first
  end

  def within_usage_limits?(feature, current_usage = 0)
    subscription = current_subscription
    return false unless subscription

    limits = subscription.plan_limits
    limit = limits[feature.to_s]
    
    return true if limit == -1 # Unlimited
    current_usage < limit
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.downcase.strip if subdomain.present?
  end
end
