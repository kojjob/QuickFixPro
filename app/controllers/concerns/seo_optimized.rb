module SeoOptimized
  extend ActiveSupport::Concern

  included do
    before_action :set_seo_defaults
    before_action :set_canonical_url
    after_action :set_seo_headers
  end

  private

  # Set intelligent SEO defaults based on controller and action
  def set_seo_defaults
    @seo = {
      title: generate_page_title,
      description: generate_meta_description,
      keywords: generate_keywords,
      noindex: should_noindex?,
      nofollow: should_nofollow?
    }
  end

  # Generate contextual page titles for better SEO
  def generate_page_title
    case "#{controller_name}##{action_name}"
    when "dashboard#index"
      if current_user
        "Performance Dashboard - #{current_account&.name || 'Your Account'}"
      else
        "Website Performance Monitoring Dashboard"
      end

    when "websites#index"
      "Your Monitored Websites - Performance Overview"

    when "websites#show"
      if @website
        "#{@website.name} - Performance Analysis & Optimization"
      else
        "Website Performance Details"
      end

    when "websites#new", "websites#create"
      "Add New Website - Start Performance Monitoring"

    when "audit_reports#index"
      "Performance Audit History - #{@website&.name || 'Website'}"

    when "audit_reports#show"
      if @audit_report && @website
        "Performance Audit Results - #{@website.name} (Score: #{@audit_report.overall_score&.round})"
      else
        "Website Performance Audit Results"
      end

    when "pages#pricing"
      "Pricing Plans - Website Performance Monitoring"

    when "pages#about"
      "About SpeedBoost - Professional Website Performance Optimization"

    when "pages#contact"
      "Contact Us - Get Help with Website Performance"

    when "home#index"
      "Professional Website Performance Optimization & Core Web Vitals Monitoring"

    else
      # Fallback to humanized action name
      action_name.humanize
    end
  end

  # Generate contextual meta descriptions
  def generate_meta_description
    case "#{controller_name}##{action_name}"
    when "dashboard#index"
      "Monitor your website performance with real-time Core Web Vitals tracking, " \
      "automated audits, and actionable optimization recommendations."

    when "websites#index"
      "View all your monitored websites, track performance scores, and identify " \
      "optimization opportunities across your web properties."

    when "websites#show"
      if @website
        "Comprehensive performance analysis for #{@website.name}. View Core Web Vitals, " \
        "get optimization recommendations, and track improvement over time."
      else
        "Detailed website performance analysis with Core Web Vitals monitoring and optimization recommendations."
      end

    when "audit_reports#show"
      if @audit_report
        score_text = @audit_report.overall_score ? " Performance score: #{@audit_report.overall_score.round}" : ""
        "Detailed performance audit results with actionable recommendations.#{score_text}. " \
        "Improve your Core Web Vitals and search engine rankings."
      else
        "Complete website performance audit with Core Web Vitals analysis and optimization guidance."
      end

    when "pages#pricing"
      "Choose the perfect plan for your website performance monitoring needs. " \
      "Plans start at $29/month with unlimited Core Web Vitals tracking."

    when "pages#about"
      "SpeedBoost helps businesses optimize website performance through automated audits, " \
      "Core Web Vitals monitoring, and expert recommendations. Trusted by 1000+ companies."

    when "home#index"
      "Professional website performance optimization platform. Automated Core Web Vitals monitoring, " \
      "Lighthouse audits, and actionable recommendations to boost your search rankings and user experience."

    else
      "Professional website performance optimization and monitoring platform"
    end
  end

  # Generate relevant keywords for each page
  def generate_keywords
    base_keywords = [
      "website performance",
      "core web vitals",
      "site speed optimization",
      "lighthouse audit",
      "page speed insights"
    ]

    case "#{controller_name}##{action_name}"
    when "dashboard#index"
      base_keywords + [ "performance dashboard", "website monitoring", "speed metrics" ]

    when "websites#index", "websites#show"
      base_keywords + [ "website analysis", "performance tracking", "speed monitoring" ]

    when "audit_reports#show", "audit_reports#index"
      base_keywords + [ "performance audit", "website audit report", "speed analysis" ]

    when "pages#pricing"
      base_keywords + [ "website monitoring pricing", "performance tools cost", "site speed tools" ]

    when "pages#about"
      base_keywords + [ "website optimization company", "performance consultancy", "speed optimization service" ]

    when "home#index"
      base_keywords + [
        "website speed test",
        "performance optimization tool",
        "core web vitals monitoring",
        "lighthouse performance",
        "page speed optimization"
      ]

    else
      base_keywords
    end
  end

  # Determine if page should be noindexed
  def should_noindex?
    # Don't index admin, internal, or user-specific pages
    return true if controller_name.in?(%w[admin internal debug])
    return true if action_name.in?(%w[edit create update destroy])
    return true if params[:preview].present?

    # Don't index empty or error states
    case "#{controller_name}##{action_name}"
    when "websites#show"
      @website.blank?
    when "audit_reports#show"
      @audit_report.blank?
    else
      false
    end
  end

  # Determine if page should be nofollowed
  def should_nofollow?
    # Nofollow user-specific or sensitive pages
    action_name.in?(%w[edit new create update destroy]) ||
    controller_name.in?(%w[sessions registrations passwords confirmations unlocks])
  end

  # Set canonical URL to prevent duplicate content issues
  def set_canonical_url
    @canonical_url = case "#{controller_name}##{action_name}"
    when "websites#show"
                      @website ? website_url(@website) : nil
    when "audit_reports#show"
                      if @audit_report && @website
                        website_audit_report_url(@website, @audit_report)
                      end
    else
                      request.original_url.split("?").first # Remove query parameters
    end
  end

  # Set SEO-friendly HTTP headers
  def set_seo_headers
    # Cache public pages for better SEO crawling
    if request.get? && !user_signed_in? && should_cache_page?
      expires_in 1.hour, public: true
      response.headers["Vary"] = "Accept-Encoding"
    end

    # Set language header
    response.headers["Content-Language"] = "en"

    # Optimize for Core Web Vitals
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
  end

  # Determine which pages should be cached for SEO
  def should_cache_page?
    return false if Rails.env.development?

    # Cache public marketing pages
    controller_name.in?(%w[home pages]) ||
    (controller_name == "websites" && action_name == "show" && @website&.public?) ||
    (controller_name == "audit_reports" && action_name == "show" && @audit_report&.public?)
  end

  protected

  # Helper to override SEO data in controllers
  def set_seo(title: nil, description: nil, keywords: nil, canonical_url: nil,
              noindex: nil, nofollow: nil, image: nil)
    @seo ||= {}
    @seo[:title] = title if title.present?
    @seo[:description] = description if description.present?
    @seo[:keywords] = keywords if keywords.present?
    @seo[:canonical_url] = canonical_url if canonical_url.present?
    @seo[:noindex] = noindex unless noindex.nil?
    @seo[:nofollow] = nofollow unless nofollow.nil?
    @seo[:image] = image if image.present?
  end
end
