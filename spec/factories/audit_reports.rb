FactoryBot.define do
  factory :audit_report do
    association :website
    association :triggered_by, factory: :user
    overall_score { 85 }
    audit_type { :manual }
    status { :completed }
    duration { 9.99 }
    result_summary { {} }
    error_details { nil }
    
    trait :automated do
      audit_type { :automated }
    end
    
    trait :scheduled do
      audit_type { :scheduled }
    end
    
    trait :manual do
      audit_type { :manual }
    end
    
    trait :pending do
      status { :pending }
      overall_score { nil }
    end
    
    trait :in_progress do
      status { :in_progress }
      overall_score { nil }
    end
    
    trait :completed do
      status { :completed }
    end
    
    trait :failed do
      status { :failed }
      overall_score { nil }
      error_details { "Failed to complete audit" }
    end
    
    trait :high_score do
      overall_score { 95 }
    end
    
    trait :medium_score do
      overall_score { 75 }
    end
    
    trait :low_score do
      overall_score { 45 }
    end
  end
end