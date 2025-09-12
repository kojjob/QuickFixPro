FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Test Account #{n}" }
    sequence(:subdomain) { |n| "account-#{n}" }
    status { 0 }
    created_by_id { nil }
  end
end
