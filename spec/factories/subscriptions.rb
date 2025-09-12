FactoryBot.define do
  factory :subscription do
    association :account
    plan_name { "starter" }
    status { :active }
    monthly_price { 29.00 }
    usage_limits { 
      { 
        "websites" => 5, 
        "monthly_audits" => 100, 
        "users" => 2,
        "api_requests" => 1000,
        "historical_data_months" => 3,
        "support_level" => "email"
      } 
    }
    plan_features { 
      { 
        "real_time_monitoring" => true, 
        "performance_alerts" => true,
        "basic_recommendations" => true
      } 
    }
    current_usage { {} }
    billing_cycle_started_at { Time.current }
    
    # Traits for different plans
    trait :starter do
      plan_name { "starter" }
      monthly_price { 29.00 }
      usage_limits { { "websites" => 5, "monthly_audits" => 100, "users" => 2 } }
    end
    
    trait :professional do
      plan_name { "professional" }
      monthly_price { 99.00 }
      usage_limits { { "websites" => 25, "monthly_audits" => 500, "users" => 10 } }
    end
    
    trait :enterprise do
      plan_name { "enterprise" }
      monthly_price { 299.00 }
      usage_limits { { "websites" => -1, "monthly_audits" => -1, "users" => -1 } }
    end
    
    # Traits for different statuses
    trait :trial do
      status { :trial }
      trial_ends_at { 14.days.from_now }
    end
    
    trait :active do
      status { :active }
    end
    
    trait :past_due do
      status { :past_due }
    end
    
    trait :cancelled do
      status { :cancelled }
      cancelled_at { Time.current }
    end
    
    trait :expired do
      status { :expired }
    end
  end
end
