FactoryBot.define do
  factory :optimization_recommendation do
    audit_report { nil }
    website { nil }
    title { "MyString" }
    description { "MyText" }
    priority { 1 }
    estimated_savings { "MyString" }
    status { 1 }
  end
end
