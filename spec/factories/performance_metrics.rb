FactoryBot.define do
  factory :performance_metric do
    audit_report
    website { audit_report.website }
    metric_type { "lcp" }
    value { 2000 }
    unit { "ms" }
    threshold_status { :good }
    threshold_good { 2500 }
    threshold_poor { 4000 }
    score_contribution { 10 }
    
    trait :lcp do
      metric_type { "lcp" }
      value { 2000 }
      unit { "ms" }
      threshold_good { 2500 }
      threshold_poor { 4000 }
    end
    
    trait :fid do
      metric_type { "fid" }
      value { 50 }
      unit { "ms" }
      threshold_good { 100 }
      threshold_poor { 300 }
    end
    
    trait :cls do
      metric_type { "cls" }
      value { 0.05 }
      unit { "score" }
      threshold_good { 0.1 }
      threshold_poor { 0.25 }
    end
    
    trait :ttfb do
      metric_type { "ttfb" }
      value { 600 }
      unit { "ms" }
      threshold_good { 800 }
      threshold_poor { 1800 }
    end
    
    trait :needs_improvement do
      threshold_status { :needs_improvement }
      value { 3000 } # For LCP, between good and poor thresholds
    end
    
    trait :poor do
      threshold_status { :poor }
      value { 5000 } # For LCP, above poor threshold
    end
  end
end
