# Stripe Configuration
# This initializer sets up Stripe API key and handles cases where it's not configured

if Rails.env.test?
  # Use test key for test environment
  Stripe.api_key = 'sk_test_dummy_key_for_testing'
elsif Rails.env.development? || Rails.env.production?
  # Try to load from credentials or environment variable
  stripe_secret_key = Rails.application.credentials.dig(:stripe, :secret_key) || ENV['STRIPE_SECRET_KEY']
  
  if stripe_secret_key.present?
    Stripe.api_key = stripe_secret_key
  else
    # Log warning but don't fail app startup
    Rails.logger.warn "⚠️  Stripe API key not configured. Payment features will be disabled."
    Rails.logger.warn "Set STRIPE_SECRET_KEY environment variable or add to credentials."
    
    # Set a dummy key to prevent errors, but mark it as unconfigured
    Stripe.api_key = nil
  end
end

# Add a helper method to check if Stripe is configured
module StripeHelper
  def self.configured?
    Stripe.api_key.present? && !Stripe.api_key.include?('dummy')
  end
  
  def self.ensure_configured!
    unless configured?
      raise StandardError, "Stripe is not configured. Please set STRIPE_SECRET_KEY environment variable."
    end
  end
end