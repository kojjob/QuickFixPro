FactoryBot.define do
  factory :monitoring_alert do
    website
    alert_type { "performance_degradation" }
    severity { "medium" }
    message { "Performance Issue Detected" }  # Using message instead of title (title is aliased to message)
    resolved { false }
    resolved_at { nil }
    metadata { {} }

    trait :resolved do
      resolved { true }
      resolved_at { 1.hour.ago }
    end

    trait :critical do
      severity { "critical" }
      message { "Critical Alert" }
    end

    trait :high do
      severity { "high" }
      message { "High Priority Alert" }
    end

    trait :low do
      severity { "low" }
      message { "Low Priority Alert" }
    end

    trait :medium do
      severity { "medium" }
      message { "Medium Priority Alert" }
    end

    trait :availability_issue do
      alert_type { "availability_issue" }
      message { "Website Unavailable - Website returned 503 error" }
    end

    trait :security_warning do
      alert_type { "security_warning" }
      message { "Security Issue Detected - Mixed content detected on HTTPS page" }
    end
  end
end
