FactoryBot.define do
  factory :user do
    first_name { "John" }
    last_name { "Doe" }
    email { "user-#{SecureRandom.hex(4)}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    role { :member }
    account
    
    trait :owner do
      role { :owner }
    end
    
    trait :admin do
      role { :admin }
    end
    
    trait :viewer do
      role { :viewer }
    end
    
    trait :inactive do
      active { false }
    end
  end
end
