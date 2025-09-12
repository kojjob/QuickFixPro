FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { "John" }
    last_name { "Doe" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :member }
    active { true }
    association :account
    preferences { {} }
    
    # Traits for different roles
    trait :owner do
      role { :owner }
    end
    
    trait :admin do
      role { :admin }
    end
    
    trait :member do
      role { :member }
    end
    
    trait :viewer do
      role { :viewer }
    end
    
    trait :inactive do
      active { false }
    end
    
    trait :with_preferences do
      preferences { { theme: 'dark', notifications: true } }
    end
  end
end
