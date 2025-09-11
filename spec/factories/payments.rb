FactoryBot.define do
  factory :payment do
    subscription { nil }
    amount { "9.99" }
    status { "MyString" }
    payment_method { "MyString" }
    stripe_payment_intent_id { "MyString" }
    stripe_charge_id { "MyString" }
    tax_rate { "9.99" }
    refunded_at { "2025-09-11 09:24:50" }
    failed_at { "2025-09-11 09:24:50" }
    failure_reason { "MyText" }
    invoice_number { "MyString" }
    retry_count { 1 }
    metadata { "" }
  end
end
