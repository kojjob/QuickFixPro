FactoryBot.define do
  factory :audit_report do
    association :website
    triggered_by { nil }
    overall_score { 75 }
    audit_type { 0 }
    status { 0 }
    duration { 9.99 }
    raw_results { {} }
    summary_data { {} }
  end
end
