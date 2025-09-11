FactoryBot.define do
  factory :subscription do
    account { nil }
    plan_name { "MyString" }
    status { 1 }
    monthly_price { "9.99" }
    usage_limits { "" }
  end
end
