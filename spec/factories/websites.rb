FactoryBot.define do
  factory :website do
    name { "Example Website" }
    url { "https://example.com" }
    status { :active }
    monitoring_frequency { :daily }
    current_score { 85 }
    last_monitored_at { 1.day.ago }
    account
    created_by { association :user, account: account }
    
    trait :paused do
      status { :paused }
    end
    
    trait :archived do
      status { :archived }
    end
    
    trait :manual_monitoring do
      monitoring_frequency { :manual }
    end
    
    trait :weekly_monitoring do
      monitoring_frequency { :weekly }
    end
    
    trait :monthly_monitoring do
      monitoring_frequency { :monthly }
    end
    
    trait :never_monitored do
      last_monitored_at { nil }
    end
    
    trait :high_score do
      current_score { 95 }
    end
    
    trait :low_score do
      current_score { 45 }
    end
  end
end
