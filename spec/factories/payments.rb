FactoryBot.define do
  factory :payment do
    association :subscription
    amount { 99.99 }
    status { 'pending' }
    payment_method { 'credit_card' }
    stripe_payment_intent_id { nil }
    stripe_charge_id { nil }
    tax_rate { 0.0 }
    refunded_at { nil }
    failed_at { nil }
    failure_reason { nil }
    invoice_number { nil }
    retry_count { 0 }
    metadata { {} }
    
    trait :succeeded do
      status { 'succeeded' }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
    end
    
    trait :failed do
      status { 'failed' }
      failed_at { Time.current }
      failure_reason { 'Insufficient funds' }
    end
    
    trait :refunded do
      status { 'refunded' }
      refunded_at { Time.current }
      stripe_payment_intent_id { "pi_#{SecureRandom.hex(12)}" }
      stripe_charge_id { "ch_#{SecureRandom.hex(12)}" }
    end
    
    trait :processing do
      status { 'processing' }
    end
    
    trait :with_tax do
      tax_rate { 0.15 }
    end
    
    trait :with_invoice do
      invoice_number { "INV-#{Time.current.year}-#{SecureRandom.random_number(999999).to_s.rjust(6, '0')}" }
    end
    
    trait :max_retries do
      retry_count { Payment::MAX_RETRIES }
    end
  end
end
