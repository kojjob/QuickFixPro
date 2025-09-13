class WebsiteAuditJob < ApplicationJob
  queue_as :audits
  queue_with_priority 5  # Higher priority for audit jobs
  
  # Limit concurrency to prevent overloading external services
  # limits_concurrency to: 3, key: -> { "website_audit" }
  
  def perform(website_id, audit_type: 'full', triggered_by: 'scheduled')
    website = Website.find(website_id)
    
    log_job_execution("Starting website audit", 
                      website_id: website.id, 
                      audit_type: audit_type,
                      triggered_by: triggered_by)
    
    # Create audit report record
    audit_report = website.audit_reports.create!(
      audit_type: audit_type,
      status: 'running',
      initiated_by: triggered_by,
      audit_data: {
        started_at: Time.current,
        job_id: job_id,
        audit_version: '1.0'
      }
    )
    
    begin
      # Perform the audit based on type
      case audit_type
      when 'full'
        perform_full_audit(website, audit_report)
      when 'performance'
        perform_performance_audit(website, audit_report)
      when 'lighthouse'
        perform_lighthouse_audit(website, audit_report)
      when 'accessibility'
        perform_accessibility_audit(website, audit_report)
      else
        raise ArgumentError, "Unknown audit type: #{audit_type}"
      end
      
      # Mark audit as completed
      audit_report.update!(
        status: 'completed',
        completed_at: Time.current,
        audit_data: audit_report.audit_data.merge(
          completed_at: Time.current,
          duration_seconds: (Time.current - audit_report.created_at).to_i
        )
      )
      
      # Update website's current score
      if audit_report.overall_score.present?
        website.update_current_score!(audit_report.overall_score)
      end
      
      # Trigger follow-up jobs
      PerformanceAnalysisJob.perform_later(audit_report.id)
      OptimizationRecommendationJob.perform_later(audit_report.id)
      
      # Broadcast update to connected clients
      audit_report.broadcast_replace_to([website.account, :audit_reports])
      
      log_job_execution("Website audit completed successfully", 
                        audit_report_id: audit_report.id,
                        overall_score: audit_report.overall_score)
      
    rescue => e
      # Mark audit as failed
      audit_report.update!(
        status: 'failed',
        error_details: {
          error_class: e.class.name,
          error_message: e.message,
          backtrace: e.backtrace.first(10)
        }
      )
      
      log_job_execution("Website audit failed", 
                        level: :error,
                        audit_report_id: audit_report.id,
                        error: e.message)
      
      # Re-raise to trigger retry mechanism
      raise e
    end
  end
  
  private
  
  def perform_full_audit(website, audit_report)
    log_job_execution("Performing full audit", website_url: website.url)
    
    # Collect all performance metrics
    metrics = {}
    
    # Core Web Vitals
    core_vitals = measure_core_web_vitals(website.url)
    metrics.merge!(core_vitals)
    
    # Performance metrics
    performance_data = measure_performance_metrics(website.url)
    metrics.merge!(performance_data)
    
    # SEO analysis
    seo_data = analyze_seo_factors(website.url)
    metrics.merge!(seo_data)
    
    # Security check
    security_data = analyze_security(website.url)
    metrics.merge!(security_data)
    
    # Accessibility check
    accessibility_data = analyze_accessibility(website.url)
    metrics.merge!(accessibility_data)
    
    # Calculate overall score
    overall_score = calculate_overall_score(metrics)
    
    # Update audit report
    audit_report.update!(
      raw_data: metrics,
      overall_score: overall_score,
      audit_data: audit_report.audit_data.merge(
        metrics_collected: metrics.keys,
        total_checks: metrics.size
      )
    )
    
    # Store detailed metrics
    store_performance_metrics(audit_report, metrics)
  end
  
  def perform_performance_audit(website, audit_report)
    log_job_execution("Performing performance audit", website_url: website.url)
    
    metrics = {}
    
    # Focus on performance-specific metrics
    core_vitals = measure_core_web_vitals(website.url)
    performance_data = measure_performance_metrics(website.url)
    
    metrics.merge!(core_vitals)
    metrics.merge!(performance_data)
    
    overall_score = calculate_performance_score(metrics)
    
    audit_report.update!(
      raw_data: metrics,
      overall_score: overall_score,
      audit_data: audit_report.audit_data.merge(
        focus: 'performance',
        core_vitals: core_vitals,
        performance_grade: grade_from_score(overall_score)
      )
    )
    
    store_performance_metrics(audit_report, metrics)
  end
  
  def perform_lighthouse_audit(website, audit_report)
    log_job_execution("Performing Lighthouse audit", website_url: website.url)
    
    # Use Lighthouse CI or similar service
    lighthouse_data = run_lighthouse_analysis(website.url)
    
    overall_score = lighthouse_data[:performance_score] || 0
    
    audit_report.update!(
      raw_data: lighthouse_data,
      overall_score: overall_score,
      audit_data: audit_report.audit_data.merge(
        tool: 'lighthouse',
        lighthouse_version: lighthouse_data[:lighthouse_version],
        categories: lighthouse_data[:categories]&.keys || []
      )
    )
    
    store_lighthouse_metrics(audit_report, lighthouse_data)
  end
  
  def perform_accessibility_audit(website, audit_report)
    log_job_execution("Performing accessibility audit", website_url: website.url)
    
    accessibility_data = analyze_accessibility(website.url)
    overall_score = accessibility_data[:accessibility_score] || 0
    
    audit_report.update!(
      raw_data: accessibility_data,
      overall_score: overall_score,
      audit_data: audit_report.audit_data.merge(
        focus: 'accessibility',
        wcag_level: accessibility_data[:wcag_level],
        violations_count: accessibility_data[:violations]&.size || 0
      )
    )
    
    store_accessibility_metrics(audit_report, accessibility_data)
  end
  
  def measure_core_web_vitals(url)
    # Mock implementation - in production, integrate with real performance monitoring
    {
      lcp: rand(1000..4000), # Largest Contentful Paint (ms)
      fid: rand(10..300),    # First Input Delay (ms)
      cls: rand(0.0..0.5).round(3), # Cumulative Layout Shift
      ttfb: rand(100..1000), # Time to First Byte (ms)
      inp: rand(50..500)     # Interaction to Next Paint (ms)
    }
  end
  
  def measure_performance_metrics(url)
    # Mock implementation - integrate with real tools like WebPageTest, GTmetrix
    {
      page_size: rand(500..5000), # KB
      requests_count: rand(10..150),
      load_time: rand(1000..8000), # ms
      speed_index: rand(1000..6000), # ms
      time_to_interactive: rand(2000..10000) # ms
    }
  end
  
  def analyze_seo_factors(url)
    # Mock implementation - integrate with SEO analysis tools
    {
      seo_score: rand(60..100),
      meta_title_present: [true, false].sample,
      meta_description_present: [true, false].sample,
      h1_count: rand(0..3),
      image_alt_missing: rand(0..10),
      internal_links: rand(5..50)
    }
  end
  
  def analyze_security(url)
    # Mock implementation - integrate with security scanning tools
    {
      security_score: rand(70..100),
      https_enabled: [true, false].sample,
      security_headers: rand(3..8),
      vulnerabilities_count: rand(0..5),
      ssl_rating: ['A+', 'A', 'B', 'C'].sample
    }
  end
  
  def analyze_accessibility(url)
    # Mock implementation - integrate with accessibility testing tools like axe
    {
      accessibility_score: rand(60..100),
      wcag_level: ['AA', 'AAA'].sample,
      violations: (1..rand(0..10)).map do |i|
        {
          rule: "rule-#{i}",
          impact: ['minor', 'moderate', 'serious', 'critical'].sample,
          description: "Sample accessibility violation #{i}"
        }
      end
    }
  end
  
  def run_lighthouse_analysis(url)
    # Mock Lighthouse data - integrate with actual Lighthouse CI
    {
      lighthouse_version: '10.4.0',
      performance_score: rand(50..100),
      categories: {
        performance: rand(50..100),
        accessibility: rand(70..100),
        'best-practices': rand(80..100),
        seo: rand(60..100),
        pwa: rand(30..90)
      },
      audits: {
        'largest-contentful-paint': rand(1000..4000),
        'first-input-delay': rand(10..300),
        'cumulative-layout-shift': rand(0.0..0.5).round(3)
      }
    }
  end
  
  def calculate_overall_score(metrics)
    # Weight different aspects
    performance_weight = 0.4
    seo_weight = 0.2
    security_weight = 0.2
    accessibility_weight = 0.2
    
    performance_score = calculate_performance_score(metrics)
    seo_score = metrics[:seo_score] || 0
    security_score = metrics[:security_score] || 0
    accessibility_score = metrics[:accessibility_score] || 0
    
    (performance_score * performance_weight + 
     seo_score * seo_weight + 
     security_score * security_weight + 
     accessibility_score * accessibility_weight).round
  end
  
  def calculate_performance_score(metrics)
    # Calculate performance score based on Core Web Vitals and other metrics
    lcp_score = score_lcp(metrics[:lcp])
    fid_score = score_fid(metrics[:fid])
    cls_score = score_cls(metrics[:cls])
    
    # Weighted average of Core Web Vitals
    ((lcp_score + fid_score + cls_score) / 3.0).round
  end
  
  def score_lcp(lcp)
    case lcp
    when 0..2500 then 100
    when 2501..4000 then 75
    else 25
    end
  end
  
  def score_fid(fid)
    case fid
    when 0..100 then 100
    when 101..300 then 75
    else 25
    end
  end
  
  def score_cls(cls)
    case cls
    when 0..0.1 then 100
    when 0.11..0.25 then 75
    else 25
    end
  end
  
  def grade_from_score(score)
    case score
    when 90..100 then 'A'
    when 80..89 then 'B'
    when 70..79 then 'C'
    when 60..69 then 'D'
    else 'F'
    end
  end
  
  def store_performance_metrics(audit_report, metrics)
    # Store Core Web Vitals
    audit_report.performance_metrics.create!(
      metric_name: 'largest_contentful_paint',
      metric_value: metrics[:lcp],
      unit: 'ms',
      category: 'core_web_vitals',
      measurement_time: Time.current
    ) if metrics[:lcp]
    
    audit_report.performance_metrics.create!(
      metric_name: 'first_input_delay',
      metric_value: metrics[:fid],
      unit: 'ms',
      category: 'core_web_vitals',
      measurement_time: Time.current
    ) if metrics[:fid]
    
    audit_report.performance_metrics.create!(
      metric_name: 'cumulative_layout_shift',
      metric_value: metrics[:cls],
      unit: 'score',
      category: 'core_web_vitals',
      measurement_time: Time.current
    ) if metrics[:cls]
    
    # Store other performance metrics
    audit_report.performance_metrics.create!(
      metric_name: 'page_load_time',
      metric_value: metrics[:load_time],
      unit: 'ms',
      category: 'performance',
      measurement_time: Time.current
    ) if metrics[:load_time]
  end
  
  def store_lighthouse_metrics(audit_report, lighthouse_data)
    lighthouse_data[:categories]&.each do |category, score|
      audit_report.performance_metrics.create!(
        metric_name: "lighthouse_#{category.gsub('-', '_')}",
        metric_value: score,
        unit: 'score',
        category: 'lighthouse',
        measurement_time: Time.current
      )
    end
  end
  
  def store_accessibility_metrics(audit_report, accessibility_data)
    audit_report.performance_metrics.create!(
      metric_name: 'accessibility_score',
      metric_value: accessibility_data[:accessibility_score],
      unit: 'score',
      category: 'accessibility',
      measurement_time: Time.current,
      additional_data: {
        wcag_level: accessibility_data[:wcag_level],
        violations_count: accessibility_data[:violations]&.size || 0
      }
    ) if accessibility_data[:accessibility_score]
  end
end