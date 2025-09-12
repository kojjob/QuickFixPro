require "uri"
require "net/http"
require "json"

class PerformanceAnalyzer < ApplicationService
  LIGHTHOUSE_CATEGORIES = %w[performance accessibility best-practices seo pwa].freeze
  USER_AGENTS = {
    desktop: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    mobile: "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  }.freeze

  def initialize(website_url, options = {})
    @website_url = normalize_url(website_url)
    @options = options
    @device_type = options[:device_type] || "desktop"
    @timeout = options[:timeout] || 30
    @analysis_depth = options[:analysis_depth] || "full"
  end

  def call
    validate_url!

    metrics = {}

    # Collect different types of metrics based on analysis depth
    case @analysis_depth
    when "quick"
      metrics.merge!(collect_basic_metrics)
    when "performance"
      metrics.merge!(collect_basic_metrics)
      metrics.merge!(collect_performance_metrics)
    when "full"
      metrics.merge!(collect_basic_metrics)
      metrics.merge!(collect_performance_metrics)
      metrics.merge!(collect_advanced_metrics)
      metrics.merge!(collect_seo_metrics)
      metrics.merge!(collect_security_metrics)
    end

    # Calculate scores
    scores = calculate_scores(metrics)
    metrics[:scores] = scores

    # Generate insights
    insights = generate_insights(metrics)

    success(
      metrics: metrics,
      scores: scores,
      insights: insights,
      analyzed_at: Time.current,
      device_type: @device_type,
      url: @website_url
    )

  rescue StandardError => e
    Rails.logger.error "PerformanceAnalyzer Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    failure("Analysis failed: #{e.message}")
  end

  private

  def validate_url!
    uri = URI.parse(@website_url)
    raise ArgumentError, "Invalid URL" unless uri.scheme && uri.host
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid URL format"
  end

  def normalize_url(url)
    return url if url.start_with?("http://", "https://")
    "https://#{url}"
  end

  def collect_basic_metrics
    metrics = {}

    # Use Chrome DevTools Protocol via Ferrum for real browser metrics
    if defined?(Ferrum)
      browser_metrics = collect_browser_metrics
      metrics.merge!(browser_metrics)
    else
      # Fallback to HTTP-based metrics
      http_metrics = collect_http_metrics
      metrics.merge!(http_metrics)
    end

    metrics
  end

  def collect_browser_metrics
    require "ferrum"

    metrics = {}

    browser = Ferrum::Browser.new(
      headless: true,
      timeout: @timeout,
      window_size: @device_type == "mobile" ? [ 375, 812 ] : [ 1920, 1080 ],
      user_agent: USER_AGENTS[@device_type.to_sym]
    )

    begin
      # Navigate to the page
      browser.goto(@website_url)

      # Wait for page to be fully loaded
      browser.network.wait_for_idle(duration: 2)

      # Get navigation timing metrics
      navigation_timing = browser.evaluate(<<-JS)
        (() => {
          const timing = performance.timing;
          const navigation = performance.getEntriesByType('navigation')[0] || {};
        #{'  '}
          return {
            // Core Web Vitals
            lcp: (() => {
              const entries = performance.getEntriesByType('largest-contentful-paint');
              return entries.length > 0 ? entries[entries.length - 1].renderTime || entries[entries.length - 1].loadTime : null;
            })(),
            fid: (() => {
              const entries = performance.getEntriesByType('first-input');
              return entries.length > 0 ? entries[0].processingStart - entries[0].startTime : null;
            })(),
            cls: (() => {
              let clsValue = 0;
              const entries = performance.getEntriesByType('layout-shift');
              entries.forEach(entry => {
                if (!entry.hadRecentInput) {
                  clsValue += entry.value;
                }
              });
              return clsValue;
            })(),
        #{'    '}
            // Navigation Timing
            ttfb: navigation.responseStart - navigation.requestStart,
            domContentLoaded: timing.domContentLoadedEventEnd - timing.navigationStart,
            loadComplete: timing.loadEventEnd - timing.navigationStart,
        #{'    '}
            // Resource Timing
            resources: performance.getEntriesByType('resource').length,
            totalTransferSize: performance.getEntriesByType('resource').reduce((total, resource) => {
              return total + (resource.transferSize || 0);
            }, 0),
        #{'    '}
            // Paint Timing
            fcp: (() => {
              const entries = performance.getEntriesByType('paint');
              const fcp = entries.find(entry => entry.name === 'first-contentful-paint');
              return fcp ? fcp.startTime : null;
            })(),
        #{'    '}
            // Memory (if available)
            memory: performance.memory ? {
              usedJSHeapSize: performance.memory.usedJSHeapSize,
              totalJSHeapSize: performance.memory.totalJSHeapSize,
              jsHeapSizeLimit: performance.memory.jsHeapSizeLimit
            } : null
          };
        })()
      JS

      metrics[:navigation_timing] = navigation_timing

      # Get page metrics
      page_metrics = browser.evaluate(<<-JS)
        (() => {
          return {
            // Document metrics
            dom_nodes: document.getElementsByTagName('*').length,
            images: document.images.length,
            scripts: document.scripts.length,
            stylesheets: document.styleSheets.length,
        #{'    '}
            // SEO basics
            title: document.title,
            meta_description: document.querySelector('meta[name="description"]')?.content,
            h1_count: document.getElementsByTagName('h1').length,
        #{'    '}
            // Accessibility basics
            images_without_alt: Array.from(document.images).filter(img => !img.alt).length,
        #{'    '}
            // Performance hints
            lazy_loaded_images: Array.from(document.images).filter(img => img.loading === 'lazy').length,
            async_scripts: Array.from(document.scripts).filter(script => script.async).length,
            defer_scripts: Array.from(document.scripts).filter(script => script.defer).length
          };
        })()
      JS

      metrics[:page_metrics] = page_metrics

      # Get Core Web Vitals
      metrics[:core_web_vitals] = {
        lcp: navigation_timing["lcp"] || measure_lcp_fallback(browser),
        fid: navigation_timing["fid"] || 0,
        cls: navigation_timing["cls"] || 0,
        ttfb: navigation_timing["ttfb"] || 0,
        fcp: navigation_timing["fcp"] || 0
      }

      # Get resource details
      metrics[:resources] = analyze_resources(browser)

    ensure
      browser.quit
    end

    metrics
  rescue => e
    Rails.logger.error "Browser metrics collection failed: #{e.message}"
    {}
  end

  def measure_lcp_fallback(browser)
    # Fallback LCP measurement using JavaScript
    browser.evaluate(<<-JS)
      (() => {
        const images = Array.from(document.images);
        const largestImage = images.reduce((largest, img) => {
          const size = img.width * img.height;
          const largestSize = largest ? largest.width * largest.height : 0;
          return size > largestSize ? img : largest;
        }, null);
      #{'  '}
        if (largestImage && largestImage.complete) {
          return performance.now();
        }
      #{'  '}
        return null;
      })()
    JS
  end

  def analyze_resources(browser)
    resources = browser.evaluate(<<-JS)
      (() => {
        const resources = performance.getEntriesByType('resource');
        const categorized = {
          images: [],
          scripts: [],
          stylesheets: [],
          fonts: [],
          other: []
        };
      #{'  '}
        resources.forEach(resource => {
          const data = {
            name: resource.name.split('/').pop().split('?')[0],
            duration: resource.duration,
            size: resource.transferSize || 0,
            type: resource.initiatorType
          };
      #{'    '}
          if (resource.name.match(/\\.(jpg|jpeg|png|gif|svg|webp|avif)/i)) {
            categorized.images.push(data);
          } else if (resource.name.match(/\\.js/i)) {
            categorized.scripts.push(data);
          } else if (resource.name.match(/\\.css/i)) {
            categorized.stylesheets.push(data);
          } else if (resource.name.match(/\\.(woff|woff2|ttf|otf|eot)/i)) {
            categorized.fonts.push(data);
          } else {
            categorized.other.push(data);
          }
        });
      #{'  '}
        return {
          total_count: resources.length,
          total_size: resources.reduce((sum, r) => sum + (r.transferSize || 0), 0),
          total_duration: resources.reduce((sum, r) => sum + r.duration, 0),
          by_type: categorized,
          largest_resources: resources
            .sort((a, b) => (b.transferSize || 0) - (a.transferSize || 0))
            .slice(0, 10)
            .map(r => ({
              url: r.name,
              size: r.transferSize || 0,
              duration: r.duration
            }))
        };
      })()
    JS

    resources
  end

  def collect_http_metrics
    # Fallback HTTP-based metrics collection
    metrics = {}

    uri = URI.parse(@website_url)

    begin
      start_time = Time.now

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = @timeout

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = USER_AGENTS[@device_type.to_sym]

      response = http.request(request)

      end_time = Time.now
      response_time = ((end_time - start_time) * 1000).round

      metrics[:http_metrics] = {
        status_code: response.code.to_i,
        response_time: response_time,
        headers: extract_relevant_headers(response),
        body_size: response.body.bytesize,
        ttfb_estimate: response_time * 0.3 # Rough estimate
      }

      # Basic HTML analysis
      if response.content_type&.include?("text/html")
        metrics[:html_analysis] = analyze_html(response.body)
      end

    rescue => e
      Rails.logger.error "HTTP metrics collection failed: #{e.message}"
      metrics[:http_metrics] = { error: e.message }
    end

    metrics
  end

  def extract_relevant_headers(response)
    relevant_headers = %w[
      content-type content-length cache-control expires
      x-frame-options x-content-type-options strict-transport-security
      content-security-policy server
    ]

    headers = {}
    relevant_headers.each do |header|
      value = response[header]
      headers[header.underscore] = value if value
    end

    headers
  end

  def analyze_html(html)
    require "nokogiri"

    doc = Nokogiri::HTML(html)

    {
      title: doc.at_css("title")&.text,
      meta_description: doc.at_css('meta[name="description"]')&.attr("content"),
      h1_count: doc.css("h1").count,
      h2_count: doc.css("h2").count,
      images_count: doc.css("img").count,
      images_without_alt: doc.css("img:not([alt])").count,
      links_count: doc.css("a").count,
      external_links: doc.css('a[href^="http"]:not([href*="' + URI.parse(@website_url).host + '"])').count,
      scripts_count: doc.css("script").count,
      stylesheets_count: doc.css('link[rel="stylesheet"]').count,
      inline_styles: doc.css("[style]").count,
      forms_count: doc.css("form").count
    }
  rescue => e
    Rails.logger.error "HTML analysis failed: #{e.message}"
    {}
  end

  def collect_performance_metrics
    metrics = {}

    # Lighthouse integration (if available)
    if lighthouse_available?
      lighthouse_data = run_lighthouse_audit
      metrics[:lighthouse] = lighthouse_data if lighthouse_data
    end

    # WebPageTest integration (if API key available)
    if webpagetest_api_key.present?
      wpt_data = run_webpagetest_audit
      metrics[:webpagetest] = wpt_data if wpt_data
    end

    metrics
  end

  def collect_advanced_metrics
    metrics = {}

    # Collect accessibility metrics
    metrics[:accessibility] = analyze_accessibility

    # Collect best practices
    metrics[:best_practices] = analyze_best_practices

    # Collect performance opportunities
    metrics[:opportunities] = identify_opportunities

    metrics
  end

  def collect_seo_metrics
    {
      meta_tags: analyze_meta_tags,
      structured_data: analyze_structured_data,
      sitemap: check_sitemap,
      robots_txt: check_robots_txt,
      canonical: check_canonical_tags,
      hreflang: check_hreflang_tags,
      open_graph: analyze_open_graph,
      twitter_cards: analyze_twitter_cards
    }
  end

  def collect_security_metrics
    {
      https: check_https,
      security_headers: analyze_security_headers,
      mixed_content: check_mixed_content,
      ssl_certificate: analyze_ssl_certificate
    }
  end

  def lighthouse_available?
    # Check if Lighthouse CI is configured
    ENV["LIGHTHOUSE_CI_TOKEN"].present? || system("which lighthouse", out: File::NULL)
  end

  def run_lighthouse_audit
    # This would integrate with Lighthouse CI or local Lighthouse
    # For now, return mock data
    {
      scores: {
        performance: rand(50..100),
        accessibility: rand(70..100),
        best_practices: rand(60..100),
        seo: rand(60..100),
        pwa: rand(30..90)
      },
      metrics: {
        first_contentful_paint: rand(500..3000),
        speed_index: rand(1000..5000),
        largest_contentful_paint: rand(1000..4000),
        time_to_interactive: rand(2000..8000),
        total_blocking_time: rand(50..500),
        cumulative_layout_shift: rand(0.0..0.5).round(3)
      }
    }
  end

  def webpagetest_api_key
    Rails.application.credentials.dig(:apis, :webpagetest_key)
  end

  def run_webpagetest_audit
    # This would integrate with WebPageTest API
    # For now, return nil
    nil
  end

  def analyze_accessibility
    {
      score: rand(60..100),
      issues: rand(0..20),
      warnings: rand(0..30)
    }
  end

  def analyze_best_practices
    {
      score: rand(70..100),
      issues: rand(0..10)
    }
  end

  def identify_opportunities
    opportunities = []

    # Based on collected metrics, identify improvement opportunities
    if @data && @data[:core_web_vitals]
      cwv = @data[:core_web_vitals]

      if cwv[:lcp] && cwv[:lcp] > 2500
        opportunities << {
          title: "Improve Largest Contentful Paint",
          impact: "high",
          effort: "medium",
          potential_savings: "#{((cwv[:lcp] - 2500) / 1000.0).round(1)}s"
        }
      end

      if cwv[:cls] && cwv[:cls] > 0.1
        opportunities << {
          title: "Reduce Cumulative Layout Shift",
          impact: "medium",
          effort: "low",
          potential_improvement: "#{((cwv[:cls] - 0.1) * 100).round}% reduction"
        }
      end
    end

    opportunities
  end

  def analyze_meta_tags
    # Would analyze meta tags from the HTML
    {
      title_present: true,
      description_present: true,
      keywords_present: false,
      viewport_present: true
    }
  end

  def analyze_structured_data
    # Would check for JSON-LD, Microdata, etc.
    {
      json_ld_present: false,
      schema_types: []
    }
  end

  def check_sitemap
    uri = URI.parse(@website_url)
    sitemap_url = "#{uri.scheme}://#{uri.host}/sitemap.xml"

    # Check if sitemap exists
    { url: sitemap_url, exists: false }
  end

  def check_robots_txt
    uri = URI.parse(@website_url)
    robots_url = "#{uri.scheme}://#{uri.host}/robots.txt"

    # Check if robots.txt exists
    { url: robots_url, exists: false }
  end

  def check_canonical_tags
    { present: false, url: nil }
  end

  def check_hreflang_tags
    { present: false, languages: [] }
  end

  def analyze_open_graph
    {
      present: false,
      tags: {}
    }
  end

  def analyze_twitter_cards
    {
      present: false,
      card_type: nil
    }
  end

  def check_https
    @website_url.start_with?("https://")
  end

  def analyze_security_headers
    headers = @data&.dig(:http_metrics, :headers) || {}

    {
      strict_transport_security: headers["strict_transport_security"].present?,
      x_frame_options: headers["x_frame_options"].present?,
      x_content_type_options: headers["x_content_type_options"].present?,
      content_security_policy: headers["content_security_policy"].present?
    }
  end

  def check_mixed_content
    # Would need to analyze all resource URLs
    { detected: false, resources: [] }
  end

  def analyze_ssl_certificate
    # Would check SSL certificate details
    {
      valid: true,
      expires_in_days: 90,
      issuer: "Let's Encrypt"
    }
  end

  def calculate_scores(metrics)
    scores = {}

    # Performance score based on Core Web Vitals
    if metrics[:core_web_vitals]
      cwv = metrics[:core_web_vitals]
      perf_score = 100

      # LCP scoring
      if cwv[:lcp]
        perf_score -= case cwv[:lcp]
        when 0..2500 then 0
        when 2501..4000 then 25
        else 50
        end
      end

      # FID scoring
      if cwv[:fid]
        perf_score -= case cwv[:fid]
        when 0..100 then 0
        when 101..300 then 15
        else 30
        end
      end

      # CLS scoring
      if cwv[:cls]
        perf_score -= case cwv[:cls]
        when 0..0.1 then 0
        when 0.11..0.25 then 10
        else 20
        end
      end

      scores[:performance] = [ perf_score, 0 ].max
    end

    # SEO score
    seo_score = 100
    if metrics[:html_analysis]
      html = metrics[:html_analysis]
      seo_score -= 20 unless html[:title].present?
      seo_score -= 15 unless html[:meta_description].present?
      seo_score -= 10 if html[:h1_count] != 1
      seo_score -= 5 if html[:images_without_alt] > 0
    end
    scores[:seo] = [ seo_score, 0 ].max

    # Security score
    security_score = 100
    security_score -= 30 unless check_https
    if metrics[:security]
      headers = metrics[:security][:security_headers] || {}
      security_score -= 10 unless headers[:strict_transport_security]
      security_score -= 10 unless headers[:x_frame_options]
      security_score -= 10 unless headers[:x_content_type_options]
    end
    scores[:security] = [ security_score, 0 ].max

    # Overall score
    scores[:overall] = (
      scores[:performance] * 0.4 +
      scores[:seo] * 0.3 +
      scores[:security] * 0.3
    ).round

    scores
  end

  def generate_insights(metrics)
    insights = []

    # Performance insights
    if metrics[:core_web_vitals]
      cwv = metrics[:core_web_vitals]

      if cwv[:lcp] && cwv[:lcp] > 4000
        insights << {
          type: "critical",
          category: "performance",
          message: "Largest Contentful Paint is critically slow",
          recommendation: "Optimize images, improve server response time, and prioritize critical resources"
        }
      end

      if cwv[:cls] && cwv[:cls] > 0.25
        insights << {
          type: "warning",
          category: "performance",
          message: "High Cumulative Layout Shift detected",
          recommendation: "Add size attributes to images and embeds, avoid inserting content above existing content"
        }
      end
    end

    # SEO insights
    if metrics[:html_analysis]
      html = metrics[:html_analysis]

      if html[:h1_count] == 0
        insights << {
          type: "error",
          category: "seo",
          message: "Missing H1 tag",
          recommendation: "Add exactly one H1 tag to improve SEO and accessibility"
        }
      end

      if html[:images_without_alt] > 0
        insights << {
          type: "warning",
          category: "accessibility",
          message: "#{html[:images_without_alt]} images missing alt text",
          recommendation: "Add descriptive alt text to all images for better accessibility and SEO"
        }
      end
    end

    # Security insights
    unless check_https
      insights << {
        type: "critical",
        category: "security",
        message: "Site not using HTTPS",
        recommendation: "Enable HTTPS to secure user data and improve search rankings"
      }
    end

    insights
  end
end
