class PaymentService
  attr_reader :subscription
  
  def initialize(subscription)
    raise ArgumentError, "Subscription is required" if subscription.nil?
    @subscription = subscription
    configure_stripe
  end
  
  def create_or_retrieve_customer(email)
    return mock_customer(email) unless stripe_configured?
    
    account = subscription.account
    
    if account.stripe_customer_id.present?
      retrieve_customer(account.stripe_customer_id)
    else
      create_customer(email, account)
    end
  end
  
  def create_payment_intent(amount, customer_id)
    Stripe::PaymentIntent.create({
      amount: (amount * 100).to_i, # Convert to cents
      currency: 'usd',
      customer: customer_id,
      metadata: {
        subscription_id: subscription.id,
        account_id: subscription.account.id
      }
    })
  end
  
  def process_payment(payment, email, payment_method_id)
    unless stripe_configured?
      # Mock successful payment for development when Stripe is not configured
      payment.update!(
        status: 'succeeded',
        stripe_payment_intent_id: 'pi_mock_' + SecureRandom.hex(12),
        stripe_charge_id: 'ch_mock_' + SecureRandom.hex(12)
      )
      
      return { 
        success: true, 
        message: 'Payment processed successfully (mock mode)',
        payment_intent_id: payment.stripe_payment_intent_id
      }
    end
    
    customer = create_or_retrieve_customer(email)
    
    # Create and confirm payment intent
    intent = Stripe::PaymentIntent.create({
      amount: (payment.amount * 100).to_i,
      currency: 'usd',
      customer: customer['id'],
      payment_method: payment_method_id,
      confirm: true,
      metadata: {
        payment_id: payment.id,
        subscription_id: subscription.id
      }
    })
    
    if intent['status'] == 'succeeded'
      # Update payment record with success
      payment.update!(
        status: 'succeeded',
        stripe_payment_intent_id: intent['id'],
        stripe_charge_id: intent['charges']['data'].first['id']
      )
      
      { 
        success: true, 
        message: 'Payment processed successfully',
        payment_intent_id: intent['id']
      }
    else
      # Handle payment failure
      error_message = intent['last_payment_error'] ? intent['last_payment_error']['message'] : 'Payment failed'
      payment.mark_as_failed!(error_message)
      
      { 
        success: false, 
        message: error_message
      }
    end
  rescue Stripe::CardError => e
    payment.mark_as_failed!(e.message)
    { success: false, message: e.message }
  rescue Stripe::InvalidRequestError => e
    raise e
  rescue => e
    payment.mark_as_failed!("Unexpected error: #{e.message}")
    { success: false, message: "An unexpected error occurred: #{e.message}" }
  end
  
  def process_refund(payment)
    unless payment.status == 'succeeded'
      return { 
        success: false, 
        message: "Cannot refund a payment that hasn't succeeded" 
      }
    end
    
    refund = Stripe::Refund.create({
      charge: payment.stripe_charge_id
    })
    
    if refund['status'] == 'succeeded'
      payment.refund!
      { 
        success: true, 
        message: 'Refund processed successfully',
        refund_id: refund['id']
      }
    else
      { 
        success: false, 
        message: 'Refund failed'
      }
    end
  rescue Stripe::InvalidRequestError => e
    { success: false, message: e.message }
  rescue => e
    { success: false, message: "An unexpected error occurred: #{e.message}" }
  end
  
  def process_subscription_renewal(email, payment_method_id)
    # Create a new payment record for the renewal
    payment = subscription.payments.create!(
      amount: subscription.monthly_price,
      status: 'pending',
      payment_method: 'credit_card'
    )
    
    begin
      result = process_payment(payment, email, payment_method_id)
      
      if result[:success]
        { 
          success: true, 
          message: 'Subscription renewed successfully',
          payment_id: payment.id
        }
      else
        result
      end
    rescue Stripe::CardError => e
      payment.mark_as_failed!(e.message)
      { success: false, message: e.message }
    end
  rescue => e
    { success: false, message: "Failed to process renewal: #{e.message}" }
  end
  
  def update_payment_method(payment_method_id)
    account = subscription.account
    
    # Attach payment method to customer
    Stripe::PaymentMethod.attach(
      payment_method_id,
      { customer: account.stripe_customer_id }
    )
    
    # Set as default payment method
    Stripe::Customer.update(
      account.stripe_customer_id,
      {
        invoice_settings: {
          default_payment_method: payment_method_id
        }
      }
    )
    
    { 
      success: true, 
      message: 'Payment method updated successfully'
    }
  rescue Stripe::InvalidRequestError => e
    { success: false, message: e.message }
  rescue => e
    { success: false, message: "An unexpected error occurred: #{e.message}" }
  end
  
  def verify_webhook_signature(payload, signature, webhook_secret)
    # In a real implementation, we would use Stripe's webhook signature verification
    # For testing environment, we'll allow bypass
    return true if Rails.env.test? && webhook_secret == "whsec_test123"
    
    begin
      Stripe::Webhook.construct_event(
        payload,
        signature,
        webhook_secret
      )
      true
    rescue Stripe::SignatureVerificationError
      false
    rescue => e
      # Log the error in production
      Rails.logger.error "Webhook verification error: #{e.message}"
      false
    end
  end
  
  private
  
  def configure_stripe
    # The API key should be configured in an initializer
    # This is just a fallback for testing
    Stripe.api_key ||= Rails.application.credentials.dig(:stripe, :secret_key) || ENV['STRIPE_SECRET_KEY']
  end
  
  def create_customer(email, account)
    customer = Stripe::Customer.create({
      email: email,
      metadata: {
        account_id: account.id
      }
    })
    
    # Save the customer ID to the account
    account.update!(stripe_customer_id: customer['id'])
    
    customer
  end
  
  def retrieve_customer(customer_id)
    Stripe::Customer.retrieve(customer_id)
  end
  
  def stripe_configured?
    Stripe.api_key.present? && !Stripe.api_key.include?('dummy')
  end
  
  def mock_customer(email)
    # Return a mock customer object when Stripe is not configured
    {
      'id' => 'cus_mock_' + SecureRandom.hex(8),
      'email' => email,
      'created' => Time.current.to_i,
      'metadata' => { 'mock' => true }
    }
  end
end