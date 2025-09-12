class RobotsController < ApplicationController
  # Skip authentication for search engine crawlers
  skip_before_action :authenticate_user!
  skip_before_action :set_current_account
  skip_before_action :ensure_account_active

  def robots
    # Set appropriate content type and caching
    response.headers["Content-Type"] = "text/plain; charset=utf-8"
    expires_in 1.day, public: true

    # Generate robots.txt based on environment and configuration
    robots_content = generate_robots_txt

    render plain: robots_content, layout: false
  end

  private

  def generate_robots_txt
    if Rails.env.production? && production_ready_for_indexing?
      production_robots_txt
    elsif Rails.env.staging?
      staging_robots_txt
    else
      development_robots_txt
    end
  end

  def production_robots_txt
    <<~ROBOTS
      # SpeedBoost Website Performance Monitoring
      # https://#{request.host}

      User-agent: *
      Allow: /

      # Allow important pages for SEO
      Allow: /pricing
      Allow: /about
      Allow: /features
      Allow: /contact
      Allow: /security
      Allow: /privacy
      Allow: /terms

      # Block user-specific and admin areas
      Disallow: /dashboard
      Disallow: /admin
      Disallow: /api/
      Disallow: /users/
      Disallow: /accounts/
      Disallow: /billing/
      Disallow: /subscriptions/

      # Block authentication pages
      Disallow: /users/sign_in
      Disallow: /users/sign_up
      Disallow: /users/password
      Disallow: /users/confirmation

      # Block search and internal tools
      Disallow: /search?
      Disallow: /internal/
      Disallow: /debug/
      Disallow: /*?*

      # Block file types that shouldn't be indexed
      Disallow: /*.json$
      Disallow: /*.xml$
      Disallow: /*.csv$
      Disallow: /*.txt$

      # Allow specific crawlers for performance monitoring
      User-agent: Googlebot
      Allow: /
      Crawl-delay: 1

      User-agent: Bingbot
      Allow: /
      Crawl-delay: 2

      # Sitemap location
      Sitemap: #{sitemap_index_url(format: :xml)}

      # Host directive for preferred domain
      Host: #{canonical_host}
    ROBOTS
  end

  def staging_robots_txt
    <<~ROBOTS
      # SpeedBoost Staging Environment
      # This is a staging environment - not for public indexing

      User-agent: *
      Disallow: /

      # Block all crawling on staging
      User-agent: Googlebot
      Disallow: /

      User-agent: Bingbot#{'  '}
      Disallow: /

      # No sitemap for staging
    ROBOTS
  end

  def development_robots_txt
    <<~ROBOTS
      # SpeedBoost Development Environment
      # This is a development environment - not for indexing

      User-agent: *
      Disallow: /
    ROBOTS
  end

  def production_ready_for_indexing?
    # Check if the application is ready for search engine indexing
    return false unless Rails.application.credentials.dig(:seo, :ready_for_indexing)

    # Ensure we have essential pages
    essential_routes = %w[root pricing about contact]
    essential_routes.all? do |route_name|
      Rails.application.routes.url_helpers.respond_to?("#{route_name}_path")
    end
  rescue
    false
  end

  def canonical_host
    # Return the canonical host for this application
    Rails.application.credentials.dig(:app, :canonical_host) ||
    Rails.application.credentials.dig(:app, :domain) ||
    request.host
  end
end
