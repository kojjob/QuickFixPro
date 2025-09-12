module SeoHelper
  # Production-ready SEO meta tag generation
  def seo_meta_tags(title: nil, description: nil, keywords: nil, canonical_url: nil,
                    noindex: false, nofollow: false, image: nil, type: "website")
    # Ensure we have defaults for critical SEO elements
    seo_title = build_seo_title(title)
    seo_description = description || default_description
    seo_canonical = canonical_url || request.original_url
    seo_image = build_seo_image_url(image)

    content_for :seo_meta_tags do
      concat seo_title_tags(seo_title)
      concat seo_description_tags(seo_description)
      concat seo_canonical_tags(seo_canonical)
      concat seo_robots_tags(noindex, nofollow)
      concat seo_open_graph_tags(seo_title, seo_description, seo_image, type, seo_canonical)
      concat seo_twitter_tags(seo_title, seo_description, seo_image)
      concat seo_structured_data_tags
    end
  end

  # Dynamic page title generation following SEO best practices
  def build_seo_title(page_title)
    return app_name if page_title.blank?

    # Format: "Page Title | App Name" (optimal for SEO)
    truncate_title("#{page_title} | #{app_name}")
  end

  # Generate breadcrumb structured data
  def breadcrumb_structured_data(breadcrumbs)
    return unless breadcrumbs.present?

    items = breadcrumbs.map.with_index do |crumb, index|
      {
        "@type" => "ListItem",
        "position" => index + 1,
        "name" => crumb[:name],
        "item" => crumb[:url]
      }
    end

    structured_data = {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => items
    }

    content_tag(:script, structured_data.to_json.html_safe, type: "application/ld+json")
  end

  # Generate organization structured data for brand recognition
  def organization_structured_data
    org_data = {
      "@context" => "https://schema.org",
      "@type" => "Organization",
      "name" => app_name,
      "url" => request.base_url,
      "sameAs" => social_media_profiles,
      "contactPoint" => {
        "@type" => "ContactPoint",
        "telephone" => Rails.application.credentials.dig(:seo, :phone),
        "contactType" => "Customer Service",
        "availableLanguage" => [ "English" ]
      },
      "address" => {
        "@type" => "PostalAddress",
        "addressCountry" => "US"
      }
    }

    content_tag(:script, org_data.to_json.html_safe, type: "application/ld+json")
  end

  # Website structured data for SaaS application
  def website_structured_data
    website_data = {
      "@context" => "https://schema.org",
      "@type" => "WebSite",
      "name" => app_name,
      "url" => request.base_url,
      "potentialAction" => {
        "@type" => "SearchAction",
        "target" => "#{request.base_url}search?q={search_term_string}",
        "query-input" => "required name=search_term_string"
      }
    }

    content_tag(:script, website_data.to_json.html_safe, type: "application/ld+json")
  end

  # Software application structured data for SaaS
  def software_application_structured_data
    app_data = {
      "@context" => "https://schema.org",
      "@type" => "SoftwareApplication",
      "name" => app_name,
      "operatingSystem" => "Web Browser",
      "applicationCategory" => "WebApplication",
      "aggregateRating" => {
        "@type" => "AggregateRating",
        "ratingValue" => "4.8",
        "reviewCount" => "150"
      },
      "offers" => subscription_offers_structured_data
    }

    content_tag(:script, app_data.to_json.html_safe, type: "application/ld+json")
  end

  # Generate hreflang tags for international SEO
  def hreflang_tags(locales = {})
    return unless locales.present?

    tags = locales.map do |locale, url|
      tag(:link, rel: "alternate", hreflang: locale, href: url)
    end

    # Add x-default for international targeting
    if locales["en"].present?
      tags << tag(:link, rel: "alternate", hreflang: "x-default", href: locales["en"])
    end

    safe_join(tags)
  end

  # Performance-optimized preload tags for critical resources
  def performance_preload_tags
    content_for :preload_tags do
      # Preload critical CSS
      concat tag(:link, rel: "preload", href: asset_path("application.css"), as: "style")

      # Preload critical fonts
      if Rails.application.credentials.dig(:fonts, :preload)
        Rails.application.credentials.fonts.preload.each do |font_path|
          concat tag(:link, rel: "preload", href: font_path, as: "font", type: "font/woff2", crossorigin: "")
        end
      end
    end
  end

  private

  def seo_title_tags(title)
    content_tag(:title, title) +
    tag(:meta, property: "og:title", content: title) +
    tag(:meta, name: "twitter:title", content: title)
  end

  def seo_description_tags(description)
    tag(:meta, name: "description", content: description) +
    tag(:meta, property: "og:description", content: description) +
    tag(:meta, name: "twitter:description", content: description)
  end

  def seo_canonical_tags(url)
    tag(:link, rel: "canonical", href: url)
  end

  def seo_robots_tags(noindex, nofollow)
    robots_content = []
    robots_content << "noindex" if noindex
    robots_content << "nofollow" if nofollow
    robots_content << "index,follow" if robots_content.empty?

    tag(:meta, name: "robots", content: robots_content.join(","))
  end

  def seo_open_graph_tags(title, description, image, type, url)
    tag(:meta, property: "og:title", content: title) +
    tag(:meta, property: "og:description", content: description) +
    tag(:meta, property: "og:image", content: image) +
    tag(:meta, property: "og:url", content: url) +
    tag(:meta, property: "og:type", content: type) +
    tag(:meta, property: "og:site_name", content: app_name)
  end

  def seo_twitter_tags(title, description, image)
    tag(:meta, name: "twitter:card", content: "summary_large_image") +
    tag(:meta, name: "twitter:title", content: title) +
    tag(:meta, name: "twitter:description", content: description) +
    tag(:meta, name: "twitter:image", content: image) +
    tag(:meta, name: "twitter:site", content: twitter_handle)
  end

  def seo_structured_data_tags
    content_for :structured_data do
      concat organization_structured_data
      concat website_structured_data
      concat software_application_structured_data if controller_name == "home" && action_name == "index"
    end
  end

  def truncate_title(title, max_length = 60)
    return title if title.length <= max_length
    title.truncate(max_length, separator: " ")
  end

  def build_seo_image_url(image)
    return nil unless image.present?

    # Handle both asset paths and full URLs
    image.start_with?("http") ? image : asset_url(image)
  end

  def app_name
    Rails.application.credentials.dig(:app, :name) || "SpeedBoost"
  end

  def default_description
    "Professional website performance optimization and Core Web Vitals monitoring. " \
    "Get actionable insights, automated audits, and expert recommendations to boost your site speed."
  end

  def social_media_profiles
    [
      Rails.application.credentials.dig(:social, :twitter),
      Rails.application.credentials.dig(:social, :linkedin),
      Rails.application.credentials.dig(:social, :github)
    ].compact
  end

  def twitter_handle
    Rails.application.credentials.dig(:social, :twitter_handle) || "@speedboost"
  end

  def subscription_offers_structured_data
    Subscription::PLAN_PRICES.map do |plan_name, price|
      {
        "@type" => "Offer",
        "name" => "#{plan_name.humanize} Plan",
        "price" => price.to_s,
        "priceCurrency" => "USD",
        "availability" => "https://schema.org/InStock"
      }
    end
  end
end
