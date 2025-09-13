FactoryBot.define do
  factory :website do
    sequence(:name) { |n| "Website #{n}" }
    sequence(:url) { |n| "https://example#{n}.com" }
    status { :active }
    monitoring_frequency { :daily }
    association :account
    association :created_by, factory: :user
    current_score { nil }
    last_monitored_at { nil }
    public_showcase { false }
    monitoring_settings { {} }
    notification_settings { {} }
    alerts_enabled { true }
    description { nil }
    
    # Traits for different statuses
    trait :active do
      status { :active }
    end
    
    trait :paused do
      status { :paused }
    end
    
    trait :archived do
      status { :archived }
    end
    
    # Traits for monitoring frequencies
    trait :manual do
      monitoring_frequency { :manual }
    end
    
    trait :daily do
      monitoring_frequency { :daily }
    end
    
    trait :weekly do
      monitoring_frequency { :weekly }
    end
    
    trait :monthly do
      monitoring_frequency { :monthly }
    end
    
    # Traits for different scores
    trait :high_score do
      current_score { 95 }
      last_monitored_at { 1.hour.ago }
    end
    
    trait :medium_score do
      current_score { 75 }
      last_monitored_at { 1.hour.ago }
    end
    
    trait :low_score do
      current_score { 45 }
      last_monitored_at { 1.hour.ago }
    end
    
    trait :public do
      public_showcase { true }
    end
    
    trait :overdue_daily do
      monitoring_frequency { :daily }
      last_monitored_at { 2.days.ago }
    end
    
    trait :overdue_weekly do
      monitoring_frequency { :weekly }
      last_monitored_at { 8.days.ago }
    end
    
    trait :overdue_monthly do
      monitoring_frequency { :monthly }
      last_monitored_at { 32.days.ago }
    end
  end
end