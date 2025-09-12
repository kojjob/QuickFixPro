class PagesController < ApplicationController
  # Skip authentication for public pages
  skip_before_action :authenticate_user!
  skip_before_action :set_current_account
  skip_before_action :ensure_account_active

  # SEO-optimized static pages
  before_action :set_page_cache_headers

  def pricing
    set_seo(
      title: "Pricing Plans - Website Performance Monitoring Starting at $29/month",
      description: "Choose the perfect plan for your website performance monitoring needs. " \
                  "Automated Core Web Vitals tracking, Lighthouse audits, and expert recommendations. " \
                  "14-day free trial included.",
      keywords: [
        "website performance monitoring pricing",
        "core web vitals monitoring cost",
        "lighthouse audit tool pricing",
        "site speed monitoring plans",
        "performance optimization pricing",
        "web vitals tracking cost"
      ]
    )

    @pricing_plans = load_detailed_pricing_plans
    @frequently_asked_questions = load_pricing_faqs
    @plan_comparison_features = load_plan_comparison_features
  end

  def about
    set_seo(
      title: "About SpeedBoost - Professional Website Performance Optimization Platform",
      description: "Learn about SpeedBoost's mission to help businesses optimize website performance " \
                  "through automated audits, Core Web Vitals monitoring, and expert recommendations. " \
                  "Trusted by 1000+ companies worldwide.",
      keywords: [
        "website optimization company",
        "performance monitoring platform",
        "core web vitals experts",
        "site speed optimization service",
        "web performance consultancy"
      ]
    )

    @company_stats = load_company_statistics
    @team_members = load_team_information
    @company_values = load_company_values
    @technology_stack = load_technology_overview
  end

  def contact
    set_seo(
      title: "Contact SpeedBoost - Get Help with Website Performance Optimization",
      description: "Get in touch with our website performance experts. Technical support, " \
                  "sales inquiries, and partnership opportunities. We're here to help optimize your site speed.",
      keywords: [
        "contact website performance experts",
        "site speed optimization support",
        "core web vitals help",
        "performance monitoring support"
      ]
    )

    @contact_methods = load_contact_information
    @support_resources = load_support_resources
    @office_locations = load_office_information
  end

  def privacy
    set_seo(
      title: "Privacy Policy - SpeedBoost Website Performance Monitoring",
      description: "Learn how SpeedBoost protects your data and privacy while monitoring website performance. " \
                  "GDPR compliant data processing and transparent privacy practices.",
      noindex: false # Privacy pages should be indexed for transparency
    )

    @last_updated = Date.new(2024, 1, 1)
    @gdpr_compliance = true
    @data_retention_period = "2 years"
  end

  def terms
    set_seo(
      title: "Terms of Service - SpeedBoost Website Performance Platform",
      description: "Terms of service and user agreement for SpeedBoost website performance monitoring platform. " \
                  "Fair and transparent terms for our performance optimization services.",
      noindex: false # Terms should be indexed for transparency
    )

    @last_updated = Date.new(2024, 1, 1)
    @service_availability_sla = "99.9%"
    @support_response_time = "24 hours"
  end

  def security
    set_seo(
      title: "Security & Compliance - Enterprise-Grade Website Performance Monitoring",
      description: "Learn about SpeedBoost's enterprise-grade security measures, data encryption, " \
                  "and compliance standards for website performance monitoring. SOC2 Type II certified.",
      keywords: [
        "website monitoring security",
        "performance tool compliance",
        "SOC2 certified monitoring",
        "enterprise security standards"
      ]
    )

    @security_certifications = load_security_certifications
    @compliance_standards = load_compliance_information
    @data_protection_measures = load_data_protection_info
  end

  def features
    set_seo(
      title: "Features - Comprehensive Website Performance Monitoring & Optimization",
      description: "Explore SpeedBoost's powerful features: Core Web Vitals monitoring, " \
                  "automated Lighthouse audits, performance recommendations, real-time alerts, and more.",
      keywords: [
        "website performance monitoring features",
        "core web vitals tracking",
        "lighthouse audit automation",
        "performance optimization tools",
        "site speed monitoring capabilities"
      ]
    )

    @feature_categories = load_feature_categories
    @integration_partners = load_integration_information
    @upcoming_features = load_roadmap_preview
  end

  private

  def set_page_cache_headers
    # Aggressive caching for static pages
    if request.get?
      expires_in 2.hours, public: true
      fresh_when(etag: "#{controller_name}/#{action_name}/v2", last_modified: 1.week.ago)
    end
  end

  def load_detailed_pricing_plans
    Subscription::PLAN_LIMITS.map do |plan_name, limits|
      plan_features = get_detailed_plan_features(plan_name)

      {
        id: plan_name,
        name: plan_name.humanize,
        price: Subscription::PLAN_PRICES[plan_name],
        annual_discount: calculate_annual_discount(plan_name),
        limits: limits,
        features: plan_features[:included],
        not_included: plan_features[:not_included],
        popular: plan_name == "professional",
        enterprise: plan_name == "enterprise",
        cta_text: plan_name == "enterprise" ? "Contact Sales" : "Start Free Trial",
        badge: get_plan_badge(plan_name)
      }
    end
  end

  def get_detailed_plan_features(plan_name)
    all_features = {
      "core_monitoring" => "Core Web Vitals monitoring",
      "lighthouse_audits" => "Automated Lighthouse audits",
      "performance_recommendations" => "AI-powered optimization recommendations",
      "email_alerts" => "Email alerts and notifications",
      "historical_data" => "Historical performance data",
      "mobile_tracking" => "Mobile performance tracking",
      "basic_dashboard" => "Performance dashboard",
      "email_support" => "Email support",
      "priority_support" => "Priority email support",
      "api_access" => "REST API access",
      "custom_alerts" => "Custom alert thresholds",
      "team_collaboration" => "Team collaboration tools",
      "scheduled_reports" => "Scheduled audit reports",
      "advanced_analytics" => "Advanced analytics dashboard",
      "dedicated_manager" => "Dedicated success manager",
      "white_label" => "White-label customization",
      "advanced_api" => "Advanced API access",
      "custom_integrations" => "Custom integrations",
      "sla_guarantee" => "SLA guarantees (99.9% uptime)",
      "priority_features" => "Priority feature requests",
      "security_controls" => "Advanced security controls"
    }

    case plan_name
    when "starter"
      {
        included: [
          all_features["core_monitoring"],
          all_features["lighthouse_audits"],
          all_features["performance_recommendations"],
          all_features["email_alerts"],
          all_features["historical_data"],
          all_features["mobile_tracking"],
          all_features["basic_dashboard"],
          all_features["email_support"]
        ],
        not_included: [
          all_features["priority_support"],
          all_features["api_access"],
          all_features["team_collaboration"],
          all_features["white_label"]
        ]
      }
    when "professional"
      {
        included: [
          all_features["core_monitoring"],
          all_features["lighthouse_audits"],
          all_features["performance_recommendations"],
          all_features["email_alerts"],
          all_features["historical_data"],
          all_features["mobile_tracking"],
          all_features["priority_support"],
          all_features["api_access"],
          all_features["custom_alerts"],
          all_features["team_collaboration"],
          all_features["scheduled_reports"],
          all_features["advanced_analytics"]
        ],
        not_included: [
          all_features["dedicated_manager"],
          all_features["white_label"],
          all_features["custom_integrations"]
        ]
      }
    when "enterprise"
      {
        included: all_features.values,
        not_included: []
      }
    end
  end

  def calculate_annual_discount(plan_name)
    # Standard 20% annual discount
    monthly_price = Subscription::PLAN_PRICES[plan_name]
    annual_price = monthly_price * 12 * 0.8
    {
      monthly_equivalent: (annual_price / 12).round(2),
      total_savings: (monthly_price * 12 - annual_price).round(2),
      discount_percentage: 20
    }
  end

  def get_plan_badge(plan_name)
    case plan_name
    when "starter"
      nil
    when "professional"
      "Most Popular"
    when "enterprise"
      "Best Value"
    end
  end

  def load_pricing_faqs
    [
      {
        question: "Do you offer a free trial?",
        answer: "Yes! All plans include a 14-day free trial with full access to all features. " \
               "No credit card required to start."
      },
      {
        question: "Can I change plans at any time?",
        answer: "Absolutely. You can upgrade or downgrade your plan at any time. " \
               "Changes take effect immediately, and we'll prorate the billing accordingly."
      },
      {
        question: "What happens if I exceed my plan limits?",
        answer: "We'll notify you when you approach your limits. You can upgrade your plan " \
               "or we'll temporarily pause monitoring until the next billing cycle."
      },
      {
        question: "Do you offer custom enterprise plans?",
        answer: "Yes, we offer custom enterprise solutions for organizations with specific " \
               "requirements. Contact our sales team for a personalized quote."
      },
      {
        question: "Is there a setup fee?",
        answer: "No setup fees, ever. You only pay for your monthly or annual subscription."
      }
    ]
  end

  def load_plan_comparison_features
    [
      {
        category: "Monitoring & Audits",
        features: [
          { name: "Core Web Vitals tracking", starter: true, professional: true, enterprise: true },
          { name: "Lighthouse audits", starter: true, professional: true, enterprise: true },
          { name: "Mobile performance tracking", starter: true, professional: true, enterprise: true },
          { name: "Advanced performance metrics", starter: false, professional: true, enterprise: true },
          { name: "Custom performance budgets", starter: false, professional: true, enterprise: true }
        ]
      },
      {
        category: "Alerts & Notifications",
        features: [
          { name: "Email notifications", starter: true, professional: true, enterprise: true },
          { name: "Custom alert thresholds", starter: false, professional: true, enterprise: true },
          { name: "Slack/Teams integration", starter: false, professional: true, enterprise: true },
          { name: "Webhook notifications", starter: false, professional: false, enterprise: true },
          { name: "SMS alerts", starter: false, professional: false, enterprise: true }
        ]
      },
      {
        category: "Team & Collaboration",
        features: [
          { name: "Team member access", starter: "2 users", professional: "10 users", enterprise: "Unlimited" },
          { name: "Role-based permissions", starter: false, professional: true, enterprise: true },
          { name: "Shared dashboards", starter: false, professional: true, enterprise: true },
          { name: "Comment & annotation system", starter: false, professional: false, enterprise: true }
        ]
      }
    ]
  end

  def load_company_statistics
    {
      founded_year: 2023,
      websites_monitored: 50000,
      performance_improvements: "40% average",
      customers_served: 1200,
      uptime_guarantee: "99.9%",
      team_size: 25,
      countries_served: 85
    }
  end

  def load_team_information
    [
      {
        name: "Alex Chen",
        role: "CEO & Co-Founder",
        bio: "Former Google Web Performance team lead with 10+ years optimizing sites at scale.",
        image: "team-alex.jpg"
      },
      {
        name: "Sarah Rodriguez",
        role: "CTO & Co-Founder",
        bio: "Ex-Netflix engineering director specializing in real-time performance monitoring.",
        image: "team-sarah.jpg"
      },
      {
        name: "Marcus Johnson",
        role: "VP of Engineering",
        bio: "Former Shopify performance architect who scaled monitoring for millions of stores.",
        image: "team-marcus.jpg"
      }
    ]
  end

  def load_company_values
    [
      {
        title: "Performance First",
        description: "We believe fast websites create better user experiences and drive business success."
      },
      {
        title: "Data-Driven Insights",
        description: "Every recommendation is backed by real performance data and industry best practices."
      },
      {
        title: "Customer Success",
        description: "Your website's performance improvement is our primary measure of success."
      },
      {
        title: "Continuous Innovation",
        description: "We constantly evolve our platform to match the latest web performance standards."
      }
    ]
  end

  def load_technology_overview
    {
      infrastructure: [ "AWS", "PostgreSQL", "Redis", "Docker" ],
      monitoring: [ "Chrome DevTools", "Lighthouse", "WebPageTest", "Real User Monitoring" ],
      security: [ "SOC2 Type II", "GDPR Compliant", "256-bit Encryption", "Regular Pen Testing" ]
    }
  end

  def load_contact_information
    [
      {
        type: "Sales",
        email: "sales@speedboost.dev",
        phone: "+1 (555) 123-SPEED",
        description: "Questions about plans, pricing, or enterprise solutions"
      },
      {
        type: "Technical Support",
        email: "support@speedboost.dev",
        response_time: "< 4 hours",
        description: "Help with setup, troubleshooting, or technical questions"
      },
      {
        type: "Partnerships",
        email: "partners@speedboost.dev",
        description: "Integration partnerships, reseller opportunities, or collaborations"
      }
    ]
  end

  def load_support_resources
    [
      { title: "Documentation", url: "/docs", description: "Complete guides and API documentation" },
      { title: "Help Center", url: "/help", description: "Frequently asked questions and tutorials" },
      { title: "Community Forum", url: "/community", description: "Connect with other users and experts" },
      { title: "Status Page", url: "/status", description: "Real-time system status and uptime" }
    ]
  end

  def load_office_information
    [
      {
        city: "San Francisco",
        address: "123 Performance Way, San Francisco, CA 94105",
        timezone: "PST/PDT"
      },
      {
        city: "New York",
        address: "456 Speed Street, New York, NY 10001",
        timezone: "EST/EDT"
      }
    ]
  end

  def load_security_certifications
    [
      {
        name: "SOC 2 Type II",
        description: "Independently audited security and availability controls",
        valid_until: "2024-12-31"
      },
      {
        name: "GDPR Compliant",
        description: "Full compliance with EU data protection regulations",
        status: "Certified"
      },
      {
        name: "ISO 27001",
        description: "Information security management system certification",
        status: "In Progress"
      }
    ]
  end

  def load_compliance_information
    {
      data_encryption: "AES-256 encryption at rest and in transit",
      access_controls: "Multi-factor authentication and role-based access",
      audit_logging: "Complete audit trail of all data access and changes",
      data_residency: "Choose your data storage region (US, EU, APAC)",
      retention_policy: "Automated data retention and deletion policies"
    }
  end

  def load_data_protection_info
    {
      backup_frequency: "Continuous with point-in-time recovery",
      disaster_recovery: "Multi-region redundancy with <1 hour RTO",
      penetration_testing: "Quarterly third-party security audits",
      vulnerability_management: "Automated scanning and patch management",
      incident_response: "24/7 security monitoring and response team"
    }
  end

  def load_feature_categories
    [
      {
        name: "Performance Monitoring",
        description: "Comprehensive website speed and performance tracking",
        features: [
          "Core Web Vitals monitoring (LCP, FID, CLS)",
          "Real User Monitoring (RUM) data collection",
          "Synthetic monitoring with global test locations",
          "Mobile and desktop performance tracking",
          "Historical performance trend analysis"
        ]
      },
      {
        name: "Automated Audits",
        description: "Regular performance audits with actionable insights",
        features: [
          "Lighthouse performance audits",
          "SEO and accessibility scoring",
          "Best practices compliance checking",
          "Progressive Web App (PWA) analysis",
          "Scheduled audit automation"
        ]
      },
      {
        name: "Optimization Recommendations",
        description: "AI-powered suggestions to improve website performance",
        features: [
          "Personalized optimization recommendations",
          "Implementation priority scoring",
          "Code-level improvement suggestions",
          "Image and asset optimization guidance",
          "Third-party service impact analysis"
        ]
      }
    ]
  end

  def load_integration_information
    [
      { name: "GitHub", description: "Automated performance checks in CI/CD" },
      { name: "Slack", description: "Real-time performance alerts and updates" },
      { name: "Jira", description: "Create tickets for performance issues" },
      { name: "Datadog", description: "Forward metrics to your monitoring stack" },
      { name: "Webhook API", description: "Custom integrations with any platform" }
    ]
  end

  def load_roadmap_preview
    [
      {
        title: "AI-Powered Performance Predictions",
        description: "Predict performance issues before they impact users",
        eta: "Q2 2024"
      },
      {
        title: "Visual Performance Comparison",
        description: "Side-by-side visual comparisons of page load experiences",
        eta: "Q3 2024"
      },
      {
        title: "Advanced A/B Testing Integration",
        description: "Performance impact analysis for A/B tests and feature flags",
        eta: "Q4 2024"
      }
    ]
  end
end
