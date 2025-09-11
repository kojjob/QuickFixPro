FactoryBot.define do
  factory :performance_metric do
    audit_report { nil }
    website { nil }
    metric_type { "MyString" }
    value { "9.99" }
    unit { "MyString" }
    threshold_status { 1 }
  end
end
