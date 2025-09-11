FactoryBot.define do
  factory :website do
    name { "MyString" }
    url { "MyString" }
    status { 1 }
    monitoring_frequency { 1 }
    account { nil }
    created_by { nil }
  end
end
