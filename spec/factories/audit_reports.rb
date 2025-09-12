FactoryBot.define do
  factory :audit_report do
    website
    triggered_by { association :user, account: website.account }
    overall_score { 85 }
    audit_type { :manual }
    status { :completed }
    started_at { 5.minutes.ago }
    completed_at { 1.minute.ago }
    duration { 240.5 }
    raw_results { { "performance" => 85, "seo" => 90, "accessibility" => 80 } }
    summary_data { { "critical_issues" => 2, "warnings" => 5, "passed" => 15 } }
    
    trait :api_triggered do
      audit_type { :api_triggered }
    end
    
    trait :scheduled do
      audit_type { :scheduled }
    end
    
    trait :pending do
      status { :pending }
      started_at { nil }
      completed_at { nil }
      overall_score { nil }
    end
    
    trait :running do
      status { :running }
      completed_at { nil }
      overall_score { nil }
    end
    
    trait :failed do
      status { :failed }
      overall_score { nil }
      error_message { "Network timeout error" }
    end
    
    trait :cancelled do
      status { :cancelled }
      overall_score { nil }
    end
    
    trait :high_score do
      overall_score { 95 }
    end
    
    trait :low_score do
      overall_score { 45 }
    end
  end
end
