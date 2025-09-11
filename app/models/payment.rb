class Payment < ApplicationRecord
  # Constants
  VALID_STATUSES = %w[pending processing succeeded failed refunded cancelled].freeze
  VALID_PAYMENT_METHODS = %w[credit_card debit_card bank_transfer paypal].freeze
  MAX_RETRIES = 3

  # Associations
  belongs_to :subscription

  # Validations
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :payment_method, presence: true, inclusion: { in: VALID_PAYMENT_METHODS }
  validates :invoice_number, uniqueness: true, allow_nil: true
  validates :stripe_payment_intent_id, uniqueness: true, allow_nil: true

  # Scopes
  scope :successful, -> { where(status: 'succeeded') }
  scope :failed, -> { where(status: 'failed') }
  scope :pending, -> { where(status: 'pending') }
  scope :current_month, -> { where(created_at: Time.current.beginning_of_month..Time.current.end_of_month) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_subscription, ->(subscription) { where(subscription: subscription) }

  # Callbacks
  before_create :generate_invoice_number
  after_initialize :set_defaults

  # Instance Methods
  def tax_amount
    return 0.0 unless tax_rate.present? && amount.present?
    (amount * tax_rate).round(2)
  end

  def total_amount
    return amount unless tax_rate.present?
    (amount + tax_amount).round(2)
  end

  def refund!
    return false unless status == 'succeeded'
    
    transaction do
      update!(
        status: 'refunded',
        refunded_at: Time.current
      )
    end
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def mark_as_failed!(reason = nil)
    update!(
      status: 'failed',
      failed_at: Time.current,
      failure_reason: reason
    )
  end

  def increment_retry!
    increment!(:retry_count)
  end

  def max_retries_reached?
    retry_count >= MAX_RETRIES
  end

  def can_retry?
    status == 'failed' && !max_retries_reached?
  end

  def succeeded?
    status == 'succeeded'
  end

  def failed?
    status == 'failed'
  end

  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def refunded?
    status == 'refunded'
  end

  def update_status!(new_status, additional_attributes = {})
    attributes_to_update = { status: new_status }
    
    case new_status
    when 'succeeded'
      attributes_to_update[:invoice_number] ||= generate_invoice_number if invoice_number.blank?
    when 'failed'
      attributes_to_update[:failed_at] = Time.current
    when 'refunded'
      attributes_to_update[:refunded_at] = Time.current
    end
    
    attributes_to_update.merge!(additional_attributes)
    update!(attributes_to_update)
  end

  private

  def set_defaults
    self.retry_count ||= 0
    self.metadata ||= {}
    self.tax_rate ||= 0.0
  end

  def generate_invoice_number
    return if invoice_number.present?
    
    # Format: INV-YYYY-NNNNNN where YYYY is year and NNNNNN is a sequential number
    year = Time.current.year
    
    # Get the last invoice number for the current year
    last_invoice = Payment.where('invoice_number LIKE ?', "INV-#{year}-%")
                          .order('invoice_number DESC')
                          .first
    
    if last_invoice && last_invoice.invoice_number =~ /INV-\d{4}-(\d{6})/
      sequence = $1.to_i + 1
    else
      sequence = 1
    end
    
    self.invoice_number = "INV-#{year}-#{sequence.to_s.rjust(6, '0')}"
  end
end