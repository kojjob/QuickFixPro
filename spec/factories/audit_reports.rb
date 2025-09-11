FactoryBot.define do
  factory :audit_report do
    website { nil }
    triggered_by { nil }
    overall_score { 1 }
    audit_type { 1 }
    status { 1 }
    duration { "9.99" }
  end
end
