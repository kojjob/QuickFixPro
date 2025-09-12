class SitemapsController < ApplicationController
  # Skip authentication for search engine crawlers
  skip_before_action :authenticate_user!
  skip_before_action :set_current_account
  skip_before_action :ensure_account_active

  # Set appropriate headers for XML sitemaps
  before_action :set_xml_headers

  def index
    # Generate sitemap index for multiple sitemaps
    @sitemaps = [
      {
        loc: sitemap_static_url(format: :xml),
        lastmod: 1.week.ago.iso8601
      },
      {
        loc: sitemap_marketing_url(format: :xml),
        lastmod: 1.day.ago.iso8601
      }
    ]

    # Add dynamic sitemaps if we have public content
    if Website.publicly_visible.exists?
      @sitemaps << {
        loc: sitemap_websites_url(format: :xml),
        lastmod: Website.publicly_visible.maximum(:updated_at)&.iso8601
      }
    end

    respond_to do |format|
      format.xml { render template: "sitemaps/index", layout: false }
    end
  end

  def static
    # Core static pages that should be indexed
    @urls = [
      {
        loc: root_url,
        changefreq: "weekly",
        priority: 1.0,
        lastmod: 1.week.ago.iso8601
      },
      {
        loc: pricing_url,
        changefreq: "monthly",
        priority: 0.9,
        lastmod: 1.month.ago.iso8601
      },
      {
        loc: about_url,
        changefreq: "monthly",
        priority: 0.8,
        lastmod: 1.month.ago.iso8601
      },
      {
        loc: features_url,
        changefreq: "monthly",
        priority: 0.8,
        lastmod: 2.weeks.ago.iso8601
      },
      {
        loc: contact_url,
        changefreq: "monthly",
        priority: 0.7,
        lastmod: 1.month.ago.iso8601
      },
      {
        loc: security_url,
        changefreq: "quarterly",
        priority: 0.6,
        lastmod: 3.months.ago.iso8601
      }
    ]

    respond_to do |format|
      format.xml { render template: "sitemaps/static", layout: false }
    end
  end

  def marketing
    # Marketing and content pages
    @urls = []

    # Add blog posts if we have a blog
    if defined?(BlogPost)
      BlogPost.published.find_each do |post|
        @urls << {
          loc: blog_post_url(post),
          changefreq: "weekly",
          priority: 0.7,
          lastmod: post.updated_at.iso8601
        }
      end
    end

    # Add case studies or success stories if available
    if defined?(CaseStudy)
      CaseStudy.published.find_each do |case_study|
        @urls << {
          loc: case_study_url(case_study),
          changefreq: "monthly",
          priority: 0.6,
          lastmod: case_study.updated_at.iso8601
        }
      end
    end

    respond_to do |format|
      format.xml { render template: "sitemaps/marketing", layout: false }
    end
  end

  def websites
    # Only include publicly visible websites (for showcase/case studies)
    @urls = []

    Website.publicly_visible.includes(:latest_audit_report).find_each do |website|
      # Only include if we have completed audit data to show
      next unless website.latest_audit_report&.completed?

      @urls << {
        loc: public_website_url(website),
        changefreq: "weekly",
        priority: 0.5,
        lastmod: website.latest_audit_report.completed_at.iso8601
      }
    end

    respond_to do |format|
      format.xml { render template: "sitemaps/websites", layout: false }
    end
  end

  private

  def set_xml_headers
    response.headers["Content-Type"] = "application/xml; charset=utf-8"

    # Cache sitemaps for search engines
    expires_in 1.day, public: true

    # Set last modified based on content updates
    fresh_when(etag: sitemap_cache_key, last_modified: sitemap_last_modified)
  end

  def sitemap_cache_key
    [
      "sitemap",
      action_name,
      Rails.application.config.cache_version_uuid,
      sitemap_content_hash
    ].join("/")
  end

  def sitemap_content_hash
    case action_name
    when "static"
      # Static pages rarely change
      Date.current.beginning_of_month.to_s
    when "marketing"
      # Marketing content changes more frequently
      Date.current.beginning_of_week.to_s
    when "websites"
      # Dynamic based on public websites
      Website.publicly_visible.maximum(:updated_at)&.to_i || 0
    else
      Date.current.to_s
    end
  end

  def sitemap_last_modified
    case action_name
    when "websites"
      Website.publicly_visible.maximum(:updated_at) || 1.week.ago
    when "marketing"
      # Use blog or content last modified if available
      if defined?(BlogPost)
        BlogPost.published.maximum(:updated_at) || 1.week.ago
      else
        1.week.ago
      end
    else
      1.week.ago
    end
  end
end
