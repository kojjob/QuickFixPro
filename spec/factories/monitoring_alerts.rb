FactoryBot.define do
  factory :monitoring_alert do
    association :website
    alert_type { :performance_degradation }
    severity { :medium }
    message { "Performance has degraded below threshold" }
    threshold_value { 80 }
    current_value { 65 }
    resolved { false }
    resolved_at { nil }
    
    trait :resolved do
      resolved { true }
      resolved_at { 1.hour.ago }
    end
    
    trait :critical do
      severity { :critical }
    end
    
    trait :high do
      severity { :high }
    end
    
    trait :medium do
      severity { :medium }
    end
    
    trait :low do
      severity { :low }
    end
  end
end