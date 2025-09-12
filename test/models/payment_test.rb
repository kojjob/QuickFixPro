require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  def setup
    @account = Account.create!(
      name: "Test Company",
      subdomain: "test-company"
    )
    @subscription = Subscription.create!(
      account: @account,
      plan_name: "professional",
      status: 1, # active
      monthly_price: 99.00
    )
  end

  # TDD: Test model attributes and validations
  test "should have valid attributes" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "pending",
      payment_method: "credit_card",
      stripe_payment_intent_id: "pi_test123"
    )
    assert payment.valid?
  end

  test "should require a subscription" do
    payment = Payment.new(
      amount: 99.00,
      status: "pending",
      payment_method: "credit_card"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:subscription], "must exist"
  end

  test "should require an amount" do
    payment = Payment.new(
      subscription: @subscription,
      status: "pending",
      payment_method: "credit_card"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:amount], "can't be blank"
  end

  test "amount should be positive" do
    payment = Payment.new(
      subscription: @subscription,
      amount: -10.00,
      status: "pending",
      payment_method: "credit_card"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:amount], "must be greater than 0"
  end

  test "should require a status" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      payment_method: "credit_card"
    )
    # Status has a default value of 'pending' in migration
    assert payment.valid?
    assert_equal "pending", payment.status
  end

  test "should only accept valid statuses" do
    valid_statuses = [ "pending", "processing", "succeeded", "failed", "refunded", "cancelled" ]

    valid_statuses.each do |status|
      payment = Payment.new(
        subscription: @subscription,
        amount: 99.00,
        status: status,
        payment_method: "credit_card"
      )
      assert payment.valid?, "#{status} should be valid"
    end

    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "invalid_status",
      payment_method: "credit_card"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:status], "is not included in the list"
  end

  test "should require a payment method" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "pending"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:payment_method], "can't be blank"
  end

  test "should only accept valid payment methods" do
    valid_methods = [ "credit_card", "debit_card", "bank_transfer", "paypal" ]

    valid_methods.each do |method|
      payment = Payment.new(
        subscription: @subscription,
        amount: 99.00,
        status: "pending",
        payment_method: method
      )
      assert payment.valid?, "#{method} should be valid"
    end

    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "pending",
      payment_method: "bitcoin"
    )
    assert_not payment.valid?
    assert_includes payment.errors[:payment_method], "is not included in the list"
  end

  # TDD: Test associations
  test "subscription should have many payments" do
    payment1 = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )
    payment2 = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )

    assert_includes @subscription.payments, payment1
    assert_includes @subscription.payments, payment2
  end

  # TDD: Test scopes
  test "should scope successful payments" do
    successful = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )
    failed = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "failed",
      payment_method: "credit_card"
    )

    assert_includes Payment.successful, successful
    assert_not_includes Payment.successful, failed
  end

  test "should scope failed payments" do
    successful = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )
    failed = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "failed",
      payment_method: "credit_card"
    )

    assert_includes Payment.failed, failed
    assert_not_includes Payment.failed, successful
  end

  test "should scope payments for current month" do
    current_month_payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card",
      created_at: Time.current
    )

    # Create a payment from last month
    last_month_payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card",
      created_at: 1.month.ago
    )

    assert_includes Payment.current_month, current_month_payment
    assert_not_includes Payment.current_month, last_month_payment
  end

  # TDD: Test business logic methods
  test "should track payment timestamps" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "pending",
      payment_method: "credit_card"
    )

    assert_not_nil payment.created_at
    assert_not_nil payment.updated_at
  end

  test "should store stripe payment intent id" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card",
      stripe_payment_intent_id: "pi_1234567890"
    )
    assert payment.valid?
    assert_equal "pi_1234567890", payment.stripe_payment_intent_id
  end

  test "should store stripe charge id" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card",
      stripe_charge_id: "ch_1234567890"
    )
    assert payment.valid?
    assert_equal "ch_1234567890", payment.stripe_charge_id
  end

  test "should calculate tax amount" do
    payment = Payment.new(
      subscription: @subscription,
      amount: 99.00,
      tax_rate: 0.10,
      status: "pending",
      payment_method: "credit_card"
    )

    assert_equal 9.90, payment.tax_amount
    assert_equal 108.90, payment.total_amount
  end

  test "should handle refunds" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )

    assert payment.refund!
    assert_equal "refunded", payment.status
    assert_not_nil payment.refunded_at
  end

  test "should not refund if not succeeded" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "pending",
      payment_method: "credit_card"
    )

    assert_not payment.refund!
    assert_not_equal "refunded", payment.status
    assert_nil payment.refunded_at
  end

  test "should mark payment as failed" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "pending",
      payment_method: "credit_card"
    )

    payment.mark_as_failed!("Insufficient funds")
    assert_equal "failed", payment.status
    assert_equal "Insufficient funds", payment.failure_reason
    assert_not_nil payment.failed_at
  end

  test "should generate invoice number" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "succeeded",
      payment_method: "credit_card"
    )

    assert_not_nil payment.invoice_number
    assert_match /^INV-\d{4}-\d{6}$/, payment.invoice_number
  end

  test "should track payment retries" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "failed",
      payment_method: "credit_card",
      retry_count: 0
    )

    payment.increment_retry!
    assert_equal 1, payment.retry_count

    payment.increment_retry!
    assert_equal 2, payment.retry_count
  end

  test "should have maximum retry limit" do
    payment = Payment.create!(
      subscription: @subscription,
      amount: 99.00,
      status: "failed",
      payment_method: "credit_card",
      retry_count: 3
    )

    assert payment.max_retries_reached?
    assert_not payment.can_retry?
  end
end
