FactoryBot.define do
  factory :optimization_task do
    association :website
    fix_type { "image_optimization" }
    status { "pending" }
    details { {} }
    error_message { nil }
  end
end
