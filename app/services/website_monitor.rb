class WebsiteMonitor < ApplicationService
  attr_reader :website, :options
  
  def initialize(website, options = {})
    @website = website
    @options = options
    @audit_type = options[:audit_type] || 'full'
    @device_type = options[:device_type] || 'desktop'
    @triggered_by = options[:triggered_by] || 'manual'
  end
  
  def call
    validate_website!
    check_monitoring_limits!
    
    # Create audit report
    audit_report = create_audit_report
    
    begin
      # Run performance analysis
      analysis_result = run_performance_analysis
      
      # Process metrics
      process_metrics(audit_report, analysis_result)
      
      # Update audit report with results
      update_audit_report(audit_report, analysis_result)
      
      # Update website status
      update_website_status(analysis_result)
      
      # Queue follow-up jobs
      queue_follow_up_jobs(audit_report)
      
      success(
        audit_report: audit_report,
        metrics: analysis_result[:metrics],
        scores: analysis_result[:scores],
        insights: analysis_result[:insights]
      )
      
    rescue => e
      handle_audit_failure(audit_report, e)
      failure("Monitoring failed: #{e.message}", audit_report: audit_report)
    end
  end
  
  private
  
  def validate_website!
    raise ArgumentError, "Website not found" unless website
    raise ArgumentError, "Website is not active" unless website.active?
    raise ArgumentError, "Invalid URL" unless website.url.present?
  end
  
  def check_monitoring_limits!
    account = website.account
    subscription = account.subscription
    
    return true unless subscription
    
    # Check monthly audit limit
    monthly_audits = account.audit_reports
                            .where('created_at > ?', 1.month.ago)
                            .count
    
    monthly_limit = subscription.plan_limits['monthly_audits'] || 100
    
    if monthly_audits >= monthly_limit
      raise StandardError, "Monthly audit limit reached (#{monthly_limit})"
    end
    
    # Check concurrent audit limit
    running_audits = account.audit_reports
                           .where(status: 'running')
                           .count
    
    concurrent_limit = subscription.plan_limits['concurrent_audits'] || 3
    
    if running_audits >= concurrent_limit
      raise StandardError, "Concurrent audit limit reached (#{concurrent_limit})"
    end
  end
  
  def create_audit_report
    website.audit_reports.create!(
      audit_type: @audit_type,
      status: 'running',
      initiated_by: @triggered_by,
      audit_data: {
        started_at: Time.current,
        device_type: @device_type,
        options: @options
      }
    )
  end
  
  def run_performance_analysis
    analyzer = PerformanceAnalyzer.new(
      website.url,
      device_type: @device_type,
      analysis_depth: @audit_type
    )
    
    result = analyzer.call
    
    unless result.success?
      raise StandardError, result.error
    end
    
    result.data
  end
  
  def process_metrics(audit_report, analysis_result)
    metrics = analysis_result[:metrics] || {}
    
    # Store Core Web Vitals
    if metrics[:core_web_vitals]
      store_core_web_vitals(audit_report, metrics[:core_web_vitals])
    end
    
    # Store performance metrics
    if metrics[:navigation_timing]
      store_navigation_timing(audit_report, metrics[:navigation_timing])
    end
    
    # Store resource metrics
    if metrics[:resources]
      store_resource_metrics(audit_report, metrics[:resources])
    end
    
    # Store page metrics
    if metrics[:page_metrics]
      store_page_metrics(audit_report, metrics[:page_metrics])
    end
    
    # Store Lighthouse metrics if available
    if metrics[:lighthouse]
      store_lighthouse_metrics(audit_report, metrics[:lighthouse])
    end
  end
  
  def store_core_web_vitals(audit_report, cwv_data)
    # Largest Contentful Paint
    if cwv_data[:lcp]
      audit_report.performance_metrics.create!(
        metric_name: 'largest_contentful_paint',
        metric_value: cwv_data[:lcp],
        unit: 'ms',
        category: 'core_web_vitals',
        measurement_time: Time.current
      )
    end
    
    # First Input Delay
    if cwv_data[:fid]
      audit_report.performance_metrics.create!(
        metric_name: 'first_input_delay',
        metric_value: cwv_data[:fid],
        unit: 'ms',
        category: 'core_web_vitals',
        measurement_time: Time.current
      )
    end
    
    # Cumulative Layout Shift
    if cwv_data[:cls]
      audit_report.performance_metrics.create!(
        metric_name: 'cumulative_layout_shift',
        metric_value: cwv_data[:cls],
        unit: 'score',
        category: 'core_web_vitals',
        measurement_time: Time.current
      )
    end
    
    # Time to First Byte
    if cwv_data[:ttfb]
      audit_report.performance_metrics.create!(
        metric_name: 'time_to_first_byte',
        metric_value: cwv_data[:ttfb],
        unit: 'ms',
        category: 'core_web_vitals',
        measurement_time: Time.current
      )
    end
    
    # First Contentful Paint
    if cwv_data[:fcp]
      audit_report.performance_metrics.create!(
        metric_name: 'first_contentful_paint',
        metric_value: cwv_data[:fcp],
        unit: 'ms',
        category: 'core_web_vitals',
        measurement_time: Time.current
      )
    end
  end
  
  def store_navigation_timing(audit_report, timing_data)
    timing_metrics = {
      'dom_content_loaded' => timing_data['domContentLoaded'],
      'load_complete' => timing_data['loadComplete'],
      'total_transfer_size' => timing_data['totalTransferSize'],
      'resource_count' => timing_data['resources']
    }
    
    timing_metrics.each do |name, value|
      next unless value
      
      unit = name.include?('size') ? 'bytes' : name.include?('count') ? 'count' : 'ms'
      
      audit_report.performance_metrics.create!(
        metric_name: name,
        metric_value: value,
        unit: unit,
        category: 'navigation_timing',
        measurement_time: Time.current
      )
    end
  end
  
  def store_resource_metrics(audit_report, resource_data)
    if resource_data[:total_size]
      audit_report.performance_metrics.create!(
        metric_name: 'total_page_size',
        metric_value: resource_data[:total_size],
        unit: 'bytes',
        category: 'resources',
        measurement_time: Time.current,
        additional_data: {
          resource_count: resource_data[:total_count],
          by_type: resource_data[:by_type]&.transform_values(&:count)
        }
      )
    end
    
    if resource_data[:total_count]
      audit_report.performance_metrics.create!(
        metric_name: 'total_requests',
        metric_value: resource_data[:total_count],
        unit: 'count',
        category: 'resources',
        measurement_time: Time.current
      )
    end
  end
  
  def store_page_metrics(audit_report, page_data)
    page_metrics = {
      'dom_nodes' => { value: page_data['dom_nodes'], unit: 'count' },
      'images_count' => { value: page_data['images'], unit: 'count' },
      'scripts_count' => { value: page_data['scripts'], unit: 'count' },
      'stylesheets_count' => { value: page_data['stylesheets'], unit: 'count' },
      'images_without_alt' => { value: page_data['images_without_alt'], unit: 'count' }
    }
    
    page_metrics.each do |name, data|
      next unless data[:value]
      
      audit_report.performance_metrics.create!(
        metric_name: name,
        metric_value: data[:value],
        unit: data[:unit],
        category: 'page_analysis',
        measurement_time: Time.current
      )
    end
  end
  
  def store_lighthouse_metrics(audit_report, lighthouse_data)
    if lighthouse_data[:scores]
      lighthouse_data[:scores].each do |category, score|
        audit_report.performance_metrics.create!(
          metric_name: "lighthouse_#{category}",
          metric_value: score,
          unit: 'score',
          category: 'lighthouse',
          measurement_time: Time.current
        )
      end
    end
    
    if lighthouse_data[:metrics]
      lighthouse_data[:metrics].each do |metric, value|
        unit = metric.to_s.include?('shift') ? 'score' : 'ms'
        
        audit_report.performance_metrics.create!(
          metric_name: metric.to_s,
          metric_value: value,
          unit: unit,
          category: 'lighthouse_metrics',
          measurement_time: Time.current
        )
      end
    end
  end
  
  def update_audit_report(audit_report, analysis_result)
    overall_score = analysis_result.dig(:scores, :overall) || 0
    
    audit_report.update!(
      status: 'completed',
      completed_at: Time.current,
      overall_score: overall_score,
      raw_data: analysis_result[:metrics],
      analysis_data: {
        scores: analysis_result[:scores],
        insights: analysis_result[:insights],
        device_type: @device_type,
        analyzed_at: analysis_result[:analyzed_at]
      },
      audit_data: audit_report.audit_data.merge(
        completed_at: Time.current,
        duration_seconds: (Time.current - audit_report.created_at).to_i
      )
    )
  end
  
  def update_website_status(analysis_result)
    overall_score = analysis_result.dig(:scores, :overall) || 0
    
    website.update!(
      current_score: overall_score,
      last_monitored_at: Time.current,
      monitoring_data: {
        last_audit_type: @audit_type,
        last_device_type: @device_type,
        last_insights_count: analysis_result[:insights]&.size || 0
      }
    )
  end
  
  def queue_follow_up_jobs(audit_report)
    # Queue performance analysis job
    PerformanceAnalysisJob.perform_later(audit_report.id)
    
    # Queue optimization recommendations job
    OptimizationRecommendationJob.perform_later(audit_report.id)
    
    # Check if we need to send alerts
    if should_send_alert?(audit_report)
      create_performance_alert(audit_report)
    end
  end
  
  def should_send_alert?(audit_report)
    # Send alert if score dropped significantly or critical issues found
    previous_score = website.audit_reports
                           .where.not(id: audit_report.id)
                           .where('created_at > ?', 7.days.ago)
                           .average(:overall_score) || 100
    
    current_score = audit_report.overall_score || 0
    score_drop = previous_score - current_score
    
    # Alert if score dropped by more than 20 points or is below 50
    score_drop > 20 || current_score < 50
  end
  
  def create_performance_alert(audit_report)
    critical_insights = audit_report.analysis_data['insights']&.select do |insight|
      insight['type'] == 'critical'
    end || []
    
    return unless critical_insights.any? || audit_report.overall_score < 50
    
    alert = website.monitoring_alerts.create!(
      alert_type: 'performance_degradation',
      severity: audit_report.overall_score < 30 ? 'critical' : 'high',
      title: 'Performance Issues Detected',
      description: build_alert_description(audit_report, critical_insights),
      alert_data: {
        audit_report_id: audit_report.id,
        overall_score: audit_report.overall_score,
        critical_insights: critical_insights,
        created_at: Time.current
      },
      created_at: Time.current,
      status: 'active'
    )
    
    # Queue notification job
    PerformanceAlertNotificationJob.perform_later(alert.id)
  end
  
  def build_alert_description(audit_report, critical_insights)
    if audit_report.overall_score < 30
      "Critical performance degradation detected. Score: #{audit_report.overall_score}/100"
    elsif critical_insights.any?
      "#{critical_insights.size} critical performance issues detected"
    else
      "Performance score dropped to #{audit_report.overall_score}/100"
    end
  end
  
  def handle_audit_failure(audit_report, error)
    audit_report.update!(
      status: 'failed',
      error_details: {
        error_class: error.class.name,
        error_message: error.message,
        backtrace: error.backtrace&.first(10)
      },
      audit_data: audit_report.audit_data.merge(
        failed_at: Time.current,
        failure_reason: error.message
      )
    )
    
    Rails.logger.error "WebsiteMonitor failed for website #{website.id}: #{error.message}"
    Rails.logger.error error.backtrace&.join("\n")
  end
end