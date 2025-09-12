FactoryBot.define do
  factory :website do
    name { "Test Website" }
    url { "https://example.com" }
    status { 0 }
    monitoring_frequency { 0 }
    association :account
    association :created_by, factory: :user
  end
end
