FactoryBot.define do
  factory :optimization_recommendation do
    association :audit_report
    association :website
    title { "Optimize Image Sizes" }
    description { "Compress and resize images to improve loading times" }
    category { "images" }
    priority { :medium }
    status { :pending }
    difficulty_level { "medium" }
    estimated_savings { "2-3 seconds load time" }
    potential_score_improvement { 10 }
    automated_fix_available { false }
    implementation_guide { "1. Compress images using tools like TinyPNG\n2. Use appropriate formats (WebP, AVIF)\n3. Implement lazy loading" }
    resources { ["https://web.dev/optimize-images/", "https://tinypng.com/"] }
    
    # Priority traits
    trait :critical do
      priority { :critical }
    end
    
    trait :high do
      priority { :high }
    end
    
    trait :medium do
      priority { :medium }
    end
    
    trait :low do
      priority { :low }
    end
    
    # Status traits
    trait :pending do
      status { :pending }
    end
    
    trait :in_progress do
      status { :in_progress }
    end
    
    trait :completed do
      status { :completed }
    end
    
    trait :dismissed do
      status { :dismissed }
    end
    
    # Difficulty traits
    trait :easy do
      difficulty_level { "easy" }
    end
    
    trait :hard do
      difficulty_level { "hard" }
    end
    
    trait :expert do
      difficulty_level { "expert" }
    end
    
    # Category traits
    trait :javascript do
      category { "javascript" }
      title { "Optimize JavaScript Delivery" }
      description { "Minimize and defer non-critical JavaScript" }
    end
    
    trait :css do
      category { "css" }
      title { "Optimize CSS Delivery" }
      description { "Inline critical CSS and defer non-critical styles" }
    end
    
    trait :caching do
      category { "caching" }
      title { "Implement Browser Caching" }
      description { "Set appropriate cache headers for static assets" }
    end
  end
end
