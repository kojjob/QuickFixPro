FactoryBot.define do
  factory :monitoring_alert do
    website { nil }
    alert_type { "MyString" }
    severity { "MyString" }
    message { "MyText" }
    resolved { false }
    resolved_at { "2025-09-11 10:45:14" }
    metadata { "" }
  end
end
