FactoryBot.define do
  factory :performance_metric do
    association :audit_report
    association :website
    metric_type { 'lcp' }
    value { 2000 }
    unit { 'ms' }
    threshold_status { :good }
    threshold_good { 2500 }
    threshold_poor { 4000 }
    score_contribution { 10 }
    
    trait :lcp do
      metric_type { 'lcp' }
      value { 2000 }
      unit { 'ms' }
    end
    
    trait :fid do
      metric_type { 'fid' }
      value { 80 }
      unit { 'ms' }
    end
    
    trait :cls do
      metric_type { 'cls' }
      value { 0.05 }
      unit { 'score' }
    end
    
    trait :ttfb do
      metric_type { 'ttfb' }
      value { 600 }
      unit { 'ms' }
    end
    
    trait :fcp do
      metric_type { 'fcp' }
      value { 1500 }
      unit { 'ms' }
    end
    
    trait :speed_index do
      metric_type { 'speed_index' }
      value { 3000 }
      unit { 'ms' }
    end
    
    trait :total_blocking_time do
      metric_type { 'total_blocking_time' }
      value { 150 }
      unit { 'ms' }
    end
    
    trait :good_performance do
      threshold_status { :good }
      value { 1000 }
    end
    
    trait :needs_improvement do
      threshold_status { :needs_improvement }
      value { 3000 }
    end
    
    trait :poor_performance do
      threshold_status { :poor }
      value { 5000 }
    end
  end
end