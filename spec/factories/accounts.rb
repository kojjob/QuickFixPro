FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Account #{n}" }
    sequence(:subdomain) { |n| "account-#{n}" }
    status { :trial }
    created_by_id { nil }
    description { "Test account description" }
    settings { {} }
    
    # Traits for different statuses
    trait :trial do
      status { :trial }
    end
    
    trait :active do
      status { :active }
    end
    
    trait :suspended do
      status { :suspended }
    end
    
    trait :cancelled do
      status { :cancelled }
    end
    
    trait :with_stripe do
      sequence(:stripe_customer_id) { |n| "cus_test#{n}" }
    end
    
    trait :with_created_by do
      association :created_by, factory: :user
    end
  end
end
