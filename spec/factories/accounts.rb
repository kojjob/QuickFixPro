FactoryBot.define do
  factory :account do
    name { "Test Account" }
    subdomain { "test-#{SecureRandom.hex(4)}" }
    status { :active }
    
    trait :trial do
      status { :trial }
    end
    
    trait :suspended do
      status { :suspended }
    end
    
    trait :cancelled do
      status { :cancelled }
    end
    
    trait :trial_expired do
      status { :trial }
      created_at { 15.days.ago }
    end
  end
end
