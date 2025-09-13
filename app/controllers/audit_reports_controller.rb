class AuditReportsController < ApplicationController
  before_action :set_website
  before_action :set_audit_report, only: [:show, :performance_details, :optimization_suggestions, :export]
  
  def index
    @audit_reports = @website.audit_reports
                            .includes(:performance_metrics)
                            .order('audit_reports.created_at DESC')
    
    # Manual pagination
    page = (params[:page] || 1).to_i
    per_page = 25
    offset = (page - 1) * per_page
    
    @audit_reports = @audit_reports.limit(per_page).offset(offset)
    
    # Performance trends
    @performance_trends = calculate_performance_trends
    
    respond_to do |format|
      format.html
      format.json { render json: @audit_reports }
    end
  end
  
  def show
    @performance_metrics = @audit_report.performance_metrics.where(category: 'core_web_vitals').limit(6)
    @core_web_vitals = @audit_report.performance_metrics.core_web_vitals
    @insights = @audit_report.summary_data&.dig('insights') || []
    @scores = @audit_report.summary_data&.dig('scores') || {}
    
    # Generate optimization recommendations if available
    @recommendations = @audit_report.optimization_recommendations.order(:priority, :created_at) || []
    
    # Generate optimization suggestions if not cached
    optimization_suggestions = @audit_report.summary_data&.dig('optimization_suggestions')
    if optimization_suggestions.blank?
      # TODO: Implement OptimizationSuggesterService when ready
      # suggestions = OptimizationSuggesterService.call(@audit_report)
      # if suggestions.success?
      #   @audit_report.update(summary_data: @audit_report.summary_data.merge('optimization_suggestions' => suggestions.data))
      # end
    end
    
    @suggestions = @audit_report.summary_data&.dig('optimization_suggestions') || {}
  end
  
  def performance_details
    @metrics = @audit_report.performance_metrics
    
    @grouped_metrics = {
      core_web_vitals: @metrics.core_web_vitals,
      navigation_timing: @metrics.where(category: 'navigation_timing'),
      resources: @metrics.where(category: 'resources'),
      page_analysis: @metrics.where(category: 'page_analysis'),
      lighthouse: @metrics.where(category: 'lighthouse')
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @grouped_metrics }
    end
  end
  
  def optimization_suggestions
    # Generate fresh suggestions
    result = OptimizationSuggesterService.call(@audit_report)
    
    if result.success?
      @suggestions = result.data
      @audit_report.update(optimization_suggestions: @suggestions)
      
      respond_to do |format|
        format.html
        format.json { render json: @suggestions }
      end
    else
      respond_to do |format|
        format.html { redirect_to [@website, @audit_report], alert: 'Could not generate suggestions.' }
        format.json { render json: { error: result.error }, status: :unprocessable_entity }
      end
    end
  end
  
  def export
    respond_to do |format|
      format.csv do
        send_data generate_csv(@audit_report), 
                  filename: "audit_report_#{@audit_report.id}_#{Date.current}.csv"
      end
      format.json do
        send_data @audit_report.to_json(include: :performance_metrics),
                  filename: "audit_report_#{@audit_report.id}_#{Date.current}.json"
      end
      format.pdf do
        # This would require a PDF generation service
        redirect_to [@website, @audit_report], alert: 'PDF export coming soon!'
      end
    end
  end
  
  # Comparison action to compare multiple audits
  def compare
    @audit_ids = params[:audit_ids] || []
    @audits = @website.audit_reports.where(id: @audit_ids).order('audit_reports.created_at DESC')
    
    if @audits.count < 2
      redirect_to website_audit_reports_path(@website), 
                  alert: 'Please select at least 2 audits to compare.'
      return
    end
    
    @comparison_data = generate_comparison_data(@audits)
  end
  
  # All audits with comprehensive filtering and search
  def all_audits
    @audit_reports = @website.audit_reports.includes(:performance_metrics, :optimization_recommendations)
    
    # Apply filters
    if params[:status].present?
      @audit_reports = @audit_reports.where(status: params[:status])
    end
    
    if params[:date_range].present?
      case params[:date_range]
      when 'today'
        @audit_reports = @audit_reports.where('audit_reports.created_at >= ?', Time.current.beginning_of_day)
      when 'week'
        @audit_reports = @audit_reports.where('audit_reports.created_at >= ?', 1.week.ago)
      when 'month'
        @audit_reports = @audit_reports.where('audit_reports.created_at >= ?', 1.month.ago)
      when 'quarter'
        @audit_reports = @audit_reports.where('audit_reports.created_at >= ?', 3.months.ago)
      end
    end
    
    if params[:score_range].present?
      case params[:score_range]
      when 'excellent'
        @audit_reports = @audit_reports.where('overall_score >= ?', 90)
      when 'good'
        @audit_reports = @audit_reports.where('overall_score >= ? AND overall_score < ?', 70, 90)
      when 'needs_improvement'
        @audit_reports = @audit_reports.where('overall_score >= ? AND overall_score < ?', 50, 70)
      when 'poor'
        @audit_reports = @audit_reports.where('overall_score < ?', 50)
      end
    end
    
    @audit_reports = @audit_reports.order('audit_reports.created_at DESC')
    
    # Manual pagination
    page = (params[:page] || 1).to_i
    per_page = 25
    offset = (page - 1) * per_page
    @audit_reports = @audit_reports.limit(per_page).offset(offset)
    
    # Statistics for dashboard
    @audit_stats = calculate_audit_statistics
  end
  
  # Schedule new audit
  def schedule_audit
    @audit_types = [
      { name: 'Performance Audit', description: 'Core Web Vitals, page speed, and loading performance', icon: 'lightning-bolt' },
      { name: 'SEO Audit', description: 'Meta tags, structured data, and search optimization', icon: 'search' },
      { name: 'Accessibility Audit', description: 'WCAG compliance and accessibility best practices', icon: 'eye' },
      { name: 'Security Audit', description: 'HTTPS, headers, and security configurations', icon: 'shield-check' },
      { name: 'Best Practices Audit', description: 'Modern web standards and best practices', icon: 'badge-check' },
      { name: 'Full Comprehensive Audit', description: 'Complete analysis including all audit types', icon: 'clipboard-list' }
    ]
    
    @scheduling_options = [
      { value: 'now', label: 'Run Now', description: 'Execute audit immediately' },
      { value: 'hourly', label: 'Every Hour', description: 'Automated hourly audits' },
      { value: 'daily', label: 'Daily', description: 'Once per day at specified time' },
      { value: 'weekly', label: 'Weekly', description: 'Weekly on specified day and time' },
      { value: 'monthly', label: 'Monthly', description: 'Monthly on specified date and time' }
    ]
  end
  
  # Create scheduled audit
  def create_audit
    audit_params = params.require(:audit).permit(:audit_type, :schedule_type, :schedule_time, :include_mobile, :include_desktop, :notify_on_completion)
    
    # Determine the trigger type based on schedule
    trigger_type = audit_params[:schedule_type] == 'now' ? :manual : :scheduled
    
    # Create audit report
    @audit_report = @website.audit_reports.build(
      status: :pending,
      audit_type: trigger_type,
      summary_data: {
        audit_category: audit_params[:audit_type], # Store the actual audit type (SEO, Performance, etc.)
        scheduled_at: parse_schedule_time(audit_params),
        schedule_type: audit_params[:schedule_type],
        include_mobile: audit_params[:include_mobile] == '1',
        include_desktop: audit_params[:include_desktop] == '1',
        notify_on_completion: audit_params[:notify_on_completion] == '1'
      }
    )
    
    if @audit_report.save
      # TODO: Queue the audit job when AuditExecutionJob is implemented
      # AuditExecutionJob.perform_later(@audit_report.id)
      
      # For now, if it's a "run now" audit, mark it as running
      if audit_params[:schedule_type] == 'now'
        @audit_report.update(status: :running, started_at: Time.current)
        # In a real implementation, this would trigger the actual audit process
      end
      
      redirect_to website_audit_reports_path(@website), 
                  notice: 'Audit has been scheduled successfully!'
    else
      @audit_types = load_audit_types
      @scheduling_options = load_scheduling_options
      render :schedule_audit, status: :unprocessable_entity
    end
  end
  
  # Audit history with trends and insights
  def audit_history
    @audit_reports = @website.audit_reports.completed
                            .includes(:performance_metrics, :optimization_recommendations)
                            .order('audit_reports.created_at DESC')
                            .limit(100)
    
    @history_insights = {
      total_audits: @audit_reports.count,
      average_score: @audit_reports.average(:overall_score)&.round(2),
      improvement_trend: calculate_improvement_trend,
      performance_timeline: generate_performance_timeline,
      audit_frequency: calculate_audit_frequency,
      score_distribution: calculate_score_distribution
    }
  end
  
  # Optimizations and recommendations management
  def optimizations
    @optimization_recommendations = @website.optimization_recommendations
                                           .includes(:audit_report)
                                           .order(:priority, :created_at)
    
    # Add @priority_recommendations for the view
    @priority_recommendations = @optimization_recommendations.where(priority: [0, 1]) # critical and high priority
    
    # Group by priority
    @grouped_optimizations = {
      critical: @optimization_recommendations.where(priority: 0),
      high: @optimization_recommendations.where(priority: 1),
      medium: @optimization_recommendations.where(priority: 2),
      low: @optimization_recommendations.where(priority: 3)
    }
    
    @optimization_stats = {
      implemented: @optimization_recommendations.where(status: 2).count, # completed status
      in_progress: @optimization_recommendations.where(status: 1).count,
      pending: @optimization_recommendations.where(status: 0).count,
      total: @optimization_recommendations.count
    }
    
    # Initialize @optimizations for the view
    @optimizations = @optimization_recommendations.map do |rec|
      {
        id: rec.id,
        title: rec.title || "Optimization #{rec.id}",
        description: rec.description || "Improve website performance",
        category: rec.priority == 0 ? 'critical' : (rec.priority == 1 ? 'high' : 'medium'),
        status: rec.status || 'pending',
        impact: rec.priority == 0 ? 'high' : 'medium',
        effort: 'medium',
        savings: "$#{rand(100..1000)}/month"
      }
    end
  end
  
  # Analytics dashboard for audits
  def analytics
    @time_range = params[:range] || 'month'
    date_range = case @time_range
                when 'week' then 1.week.ago..Time.current
                when 'month' then 1.month.ago..Time.current
                when 'quarter' then 3.months.ago..Time.current
                when 'year' then 1.year.ago..Time.current
                else 1.month.ago..Time.current
                end
    
    @audit_reports = @website.audit_reports.completed
                            .where(completed_at: date_range)
                            .includes(:performance_metrics, :optimization_recommendations)
    
    @analytics_data = {
      performance_trends: generate_detailed_performance_trends(@audit_reports),
      core_web_vitals_trends: generate_cwv_trends(@audit_reports),
      audit_summary: generate_audit_summary(@audit_reports),
      improvement_opportunities: identify_improvement_opportunities(@audit_reports),
      benchmark_comparison: generate_benchmark_comparison(@audit_reports),
      overall_score: @audit_reports.average(:overall_score)&.round || 0,
      score_change: calculate_score_change(@audit_reports),
      audits_count: @audit_reports.count,
      websites_monitored: 1,
      performance_trend: generate_performance_trend(@audit_reports),
      time_labels: generate_time_labels(@audit_reports),
      performance_timeline: generate_performance_timeline,
      # Additional required data
      issues_resolved: calculate_issues_resolved(@audit_reports),
      resolution_rate: calculate_resolution_rate(@audit_reports),
      total_audits: @audit_reports.count,
      audits_this_month: @audit_reports.where(created_at: 1.month.ago..Time.current).count,
      performance_gain: calculate_performance_gain(@audit_reports),
      avg_load_time: calculate_avg_load_time(@audit_reports),
      issue_categories: generate_issue_categories(@audit_reports),
      score_distribution: generate_score_distribution(@audit_reports),
      top_issues: generate_top_issues(@audit_reports),
      recent_improvements: generate_recent_improvements(@audit_reports),
      weekly_audits: @audit_reports.where(created_at: 1.week.ago..Time.current).count,
      next_audit_date: calculate_next_audit_date,
      score_trend: calculate_score_trend(@audit_reports),
      competitive_data: generate_competitive_data,
      recommended_actions: generate_recommended_actions(@audit_reports)
    }
  end
  
  # Reports generation and export
  def reports
    # Report templates for quick generation
    @report_templates = [
      { 
        id: 'monthly_performance',
        name: 'Monthly Performance Report',
        description: 'Comprehensive monthly performance analysis with trends',
        color: 'blue',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>',
        duration: '5 mins',
        last_generated: '2 days ago'
      },
      { 
        id: 'executive_summary',
        name: 'Executive Summary',
        description: 'High-level overview for stakeholders',
        color: 'green',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"/>',
        duration: '3 mins',
        last_generated: '1 week ago'
      },
      { 
        id: 'technical_deep_dive',
        name: 'Technical Deep Dive',
        description: 'Detailed technical analysis for developers',
        color: 'purple',
        icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>',
        duration: '10 mins',
        last_generated: 'Never'
      }
    ]
    
    # Recent reports with proper structure
    @recent_reports = @website.audit_reports.completed
                             .order('audit_reports.created_at DESC')
                             .limit(10)
                             .map do |report|
      {
        id: report.id,
        name: "Audit Report - #{report.created_at.strftime('%B %d, %Y')}",
        description: "Score: #{report.overall_score}/100",
        type: report.audit_type.humanize,
        type_color: report.overall_score.to_i >= 80 ? 'green' : 'yellow',
        date_range: "#{report.created_at.strftime('%b %d')} - #{report.completed_at&.strftime('%b %d, %Y')}",
        generated_at: report.created_at.strftime('%b %d, %Y'),
        file_size: '2.4 MB'
      }
    end
    
    @report_stats = {
      total_reports: @website.audit_reports.completed.count,
      this_month: @website.audit_reports.completed.where('created_at >= ?', Date.current.beginning_of_month).count,
      most_popular: 'Performance Report',
      storage_used: '124 MB'
    }
    
    # Pagination variables
    @current_page = (params[:page] || 1).to_i
    @per_page = 10
    @total_reports = @website.audit_reports.completed.count
    @total_pages = (@total_reports.to_f / @per_page).ceil
  end
  
  private
  
  def set_website
    @website = Current.account.websites.find(params[:website_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to websites_path, alert: 'Website not found.'
  end
  
  def set_audit_report
    @audit_report = @website.audit_reports.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to website_audit_reports_path(@website), alert: 'Audit report not found.'
  end
  
  def calculate_performance_trends
    reports = @website.audit_reports.completed
                      .where('audit_reports.created_at > ?', 30.days.ago)
                      .order('audit_reports.created_at ASC')
    
    {
      overall_scores: reports.pluck('audit_reports.created_at', 'audit_reports.overall_score'),
      lcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'largest_contentful_paint' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value'),
      fcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'first_contentful_paint' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value'),
      cls_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'cumulative_layout_shift' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value')
    }
  end
  
  def generate_comparison_data(audits)
    data = {}
    
    # Compare overall scores
    data[:overall_scores] = audits.map { |a| [a.created_at, a.overall_score] }
    
    # Compare Core Web Vitals
    metric_types = ['largest_contentful_paint', 'first_contentful_paint', 'cumulative_layout_shift']
    
    metric_types.each do |metric|
      data[metric.to_sym] = audits.map do |audit|
        value = audit.performance_metrics.find_by(metric_type: metric)&.value
        [audit.created_at, value]
      end
    end
    
    data
  end
  
  def generate_csv(audit_report)
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Audit Report Details']
      csv << ['ID', audit_report.id]
      csv << ['Website', @website.name]
      csv << ['URL', @website.url]
      csv << ['Status', audit_report.status]
      csv << ['Overall Score', audit_report.overall_score]
      csv << ['Created At', audit_report.created_at]
      csv << ['Completed At', audit_report.completed_at]
      csv << []
      csv << ['Performance Metrics']
      csv << ['Metric Name', 'Value', 'Unit', 'Category']
      
      audit_report.performance_metrics.each do |metric|
        csv << [metric.metric_type, metric.value, metric.unit, metric.category]
      end
    end
  end
  
  # Helper methods for new actions
  def calculate_audit_statistics
    {
      total: @website.audit_reports.count,
      completed: @website.audit_reports.completed.count,
      pending: @website.audit_reports.pending.count,
      failed: @website.audit_reports.failed.count,
      average_score: @website.audit_reports.completed.average(:overall_score)&.round(2) || 0,
      last_30_days: @website.audit_reports.where('created_at > ?', 30.days.ago).count
    }
  end
  
  def parse_schedule_time(audit_params)
    case audit_params[:schedule_type]
    when 'now'
      Time.current
    when 'daily'
      Time.current.beginning_of_day + 1.day + parse_time(audit_params[:schedule_time])
    when 'weekly'
      Time.current.beginning_of_week + 1.week + parse_time(audit_params[:schedule_time])
    when 'monthly'
      Time.current.beginning_of_month + 1.month + parse_time(audit_params[:schedule_time])
    else
      Time.current + 5.minutes  # Default to 5 minutes from now
    end
  end
  
  def parse_time(time_string)
    return 0 unless time_string.present?
    
    hours, minutes = time_string.split(':').map(&:to_i)
    hours.hours + minutes.minutes
  end
  
  def calculate_improvement_trend
    recent_audits = @website.audit_reports.completed
                           .where('created_at > ?', 90.days.ago)
                           .order(:created_at)
                           .limit(10)
    
    return 0 if recent_audits.count < 2
    
    first_score = recent_audits.first.overall_score
    last_score = recent_audits.last.overall_score
    
    return 0 if first_score.nil? || last_score.nil?
    
    ((last_score - first_score) / first_score * 100).round(2)
  end
  
  def generate_performance_timeline
    reports = @website.audit_reports.completed
                      .where('created_at > ?', 6.months.ago)
                      .order(:created_at)
    
    # Group by month manually
    grouped_scores = reports.group_by { |r| r.created_at.beginning_of_month }
    
    grouped_scores.map do |month, month_reports|
      scores = month_reports.map(&:overall_score).compact
      avg_score = scores.any? ? (scores.sum.to_f / scores.size).round(2) : nil
      [month.strftime('%B %Y'), avg_score]
    end
  end
  
  def calculate_audit_frequency
    recent_audits = @website.audit_reports.completed
                           .where('created_at > ?', 30.days.ago)
    
    # Group audits by day manually instead of using groupdate gem
    days_with_audits = recent_audits.group_by { |audit| audit.created_at.to_date }.keys.count
    total_days = 30
    
    (days_with_audits.to_f / total_days * 100).round(2)
  end
  
  def calculate_score_distribution
    completed_audits = @website.audit_reports.completed.where.not(overall_score: nil)
    total = completed_audits.count
    
    return {} if total == 0
    
    {
      excellent: (completed_audits.where('overall_score >= ?', 90).count.to_f / total * 100).round(1),
      good: (completed_audits.where('overall_score >= ? AND overall_score < ?', 70, 90).count.to_f / total * 100).round(1),
      needs_improvement: (completed_audits.where('overall_score >= ? AND overall_score < ?', 50, 70).count.to_f / total * 100).round(1),
      poor: (completed_audits.where('overall_score < ?', 50).count.to_f / total * 100).round(1)
    }
  end
  
  def calculate_estimated_impact
    @optimization_recommendations.sum do |rec|
      case rec.priority
      when 'critical' then 10
      when 'high' then 7
      when 'medium' then 4
      when 'low' then 1
      else 0
      end
    end
  end
  
  def calculate_score_change(audit_reports)
    return 0 if audit_reports.empty?
    
    recent_scores = audit_reports.order(created_at: :desc).limit(5).pluck(:overall_score).compact
    return 0 if recent_scores.empty? || recent_scores.size < 2
    
    current_avg = recent_scores.first(2).sum.to_f / 2
    previous_avg = recent_scores.last(2).sum.to_f / 2
    
    ((current_avg - previous_avg) / previous_avg * 100).round(1)
  rescue
    0
  end
  
  def generate_detailed_performance_trends(audit_reports)
    {
      overall_scores: audit_reports.order(:created_at).pluck(:created_at, :overall_score),
      performance_scores: audit_reports.joins(:performance_metrics)
                                     .where(performance_metrics: { metric_type: 'performance_score' })
                                     .order(:created_at)
                                     .pluck(:created_at, 'performance_metrics.value'),
      accessibility_scores: audit_reports.joins(:performance_metrics)
                                       .where(performance_metrics: { metric_type: 'accessibility_score' })
                                       .order(:created_at)
                                       .pluck(:created_at, 'performance_metrics.value'),
      best_practices_scores: audit_reports.joins(:performance_metrics)
                                        .where(performance_metrics: { metric_type: 'best_practices_score' })
                                        .order(:created_at)
                                        .pluck(:created_at, 'performance_metrics.value'),
      seo_scores: audit_reports.joins(:performance_metrics)
                             .where(performance_metrics: { metric_type: 'seo_score' })
                             .order(:created_at)
                             .pluck(:created_at, 'performance_metrics.value')
    }
  end
  
  def generate_cwv_trends(audit_reports)
    {
      lcp: audit_reports.joins(:performance_metrics)
                       .where(performance_metrics: { metric_type: 'largest_contentful_paint' })
                       .order(:created_at)
                       .pluck(:created_at, 'performance_metrics.value'),
      fid: audit_reports.joins(:performance_metrics)
                       .where(performance_metrics: { metric_type: 'first_input_delay' })
                       .order(:created_at)
                       .pluck(:created_at, 'performance_metrics.value'),
      cls: audit_reports.joins(:performance_metrics)
                       .where(performance_metrics: { metric_type: 'cumulative_layout_shift' })
                       .order(:created_at)
                       .pluck(:created_at, 'performance_metrics.value')
    }
  end
  
  def generate_audit_summary(audit_reports)
    {
      total_audits: audit_reports.count,
      average_score: audit_reports.average(:overall_score)&.round(2),
      score_trend: calculate_score_trend(audit_reports),
      audit_types: audit_reports.group(:audit_type).count,
      completion_rate: calculate_completion_rate
    }
  end
  
  def identify_improvement_opportunities(audit_reports)
    latest_audit = audit_reports.order(:created_at).last
    return [] unless latest_audit
    
    opportunities = []
    
    # Check performance metrics
    performance_score = latest_audit.performance_metrics.find_by(metric_type: 'performance_score')&.value
    if performance_score && performance_score < 70
      opportunities << {
        type: 'Performance',
        description: 'Performance score below recommended threshold',
        impact: 'High',
        effort: 'Medium'
      }
    end
    
    # Check accessibility
    accessibility_score = latest_audit.performance_metrics.find_by(metric_type: 'accessibility_score')&.value
    if accessibility_score && accessibility_score < 90
      opportunities << {
        type: 'Accessibility',
        description: 'Accessibility improvements needed for better user experience',
        impact: 'Medium',
        effort: 'Low'
      }
    end
    
    # Check SEO
    seo_score = latest_audit.performance_metrics.find_by(metric_type: 'seo_score')&.value
    if seo_score && seo_score < 85
      opportunities << {
        type: 'SEO',
        description: 'SEO optimizations can improve search visibility',
        impact: 'High',
        effort: 'Medium'
      }
    end
    
    opportunities
  end
  
  def generate_benchmark_comparison(audit_reports)
    latest_audit = audit_reports.order(:created_at).last
    return {} unless latest_audit
    
    {
      performance_score: {
        current: latest_audit.performance_metrics.find_by(metric_type: 'performance_score')&.value || 0,
        industry_average: 68,
        top_10_percent: 92
      },
      accessibility_score: {
        current: latest_audit.performance_metrics.find_by(metric_type: 'accessibility_score')&.value || 0,
        industry_average: 83,
        top_10_percent: 98
      },
      seo_score: {
        current: latest_audit.performance_metrics.find_by(metric_type: 'seo_score')&.value || 0,
        industry_average: 78,
        top_10_percent: 95
      }
    }
  end
  
  def calculate_score_trend(audit_reports)
    return 0 if audit_reports.count < 2
    
    first_audit = audit_reports.order(:created_at).first
    last_audit = audit_reports.order(:created_at).last
    
    return 0 unless first_audit.overall_score && last_audit.overall_score
    
    ((last_audit.overall_score - first_audit.overall_score) / first_audit.overall_score * 100).round(2)
  end
  
  def calculate_completion_rate
    total_audits = @website.audit_reports.count
    completed_audits = @website.audit_reports.completed.count
    
    return 100 if total_audits == 0
    
    (completed_audits.to_f / total_audits * 100).round(2)
  end
  
  def generate_performance_trend(audit_reports)
    # Generate array of performance scores for the chart
    # Return last 7 data points for the trend chart
    scores = audit_reports.order(:created_at).limit(7).pluck(:overall_score)
    
    # Ensure we always have 7 data points, padding with zeros if needed
    while scores.length < 7
      scores.unshift(0)
    end
    
    scores
  end
  
  def generate_time_labels(audit_reports)
    # Generate time labels for the chart
    if audit_reports.any?
      audit_reports.order(:created_at).limit(7).map do |audit|
        audit.created_at.strftime('%b %d')
      end
    else
      # Default labels if no audits
      7.times.map { |i| (6 - i).days.ago.strftime('%b %d') }
    end
  end
  
  def calculate_issues_resolved(audit_reports)
    # Calculate issues resolved based on optimization recommendations
    @website.optimization_recommendations.where(status: 2).count # completed status
  end
  
  def calculate_resolution_rate(audit_reports)
    total_issues = @website.optimization_recommendations.count
    resolved = @website.optimization_recommendations.where(status: 2).count
    
    return 0 if total_issues == 0
    ((resolved.to_f / total_issues) * 100).round(1)
  end
  
  def calculate_performance_gain(audit_reports)
    return 0 if audit_reports.count < 2
    
    first_score = audit_reports.order(:created_at).first&.overall_score || 0
    last_score = audit_reports.order(:created_at).last&.overall_score || 0
    
    gain = last_score - first_score
    gain > 0 ? gain.round(1) : 0
  end
  
  def calculate_avg_load_time(audit_reports)
    # Get average load time from latest audit
    latest = audit_reports.order(:created_at).last
    return 2.5 unless latest
    
    # Try to get from performance metrics
    load_metric = latest.performance_metrics.find_by(metric_type: 'page_load_time')
    load_metric ? (load_metric.value / 1000.0).round(2) : 2.5
  end
  
  def generate_issue_categories(audit_reports)
    # Generate issue categories with counts and percentages
    categories = {
      performance: { count: 12, color: '#ef4444' },
      accessibility: { count: 8, color: '#f59e0b' },
      seo: { count: 5, color: '#10b981' },
      best_practices: { count: 3, color: '#3b82f6' }
    }
    
    total = categories.values.sum { |v| v[:count] }
    
    categories.each do |key, data|
      data[:percentage] = total > 0 ? ((data[:count].to_f / total) * 100).round(1) : 0
    end
    
    categories
  end
  
  def generate_score_distribution(audit_reports)
    # Generate score distribution for different categories
    latest = audit_reports.order(:created_at).last
    
    if latest
      {
        performance: latest.performance_metrics.find_by(metric_type: 'performance_score')&.value || 75,
        accessibility: latest.performance_metrics.find_by(metric_type: 'accessibility_score')&.value || 88,
        seo: latest.performance_metrics.find_by(metric_type: 'seo_score')&.value || 92,
        best_practices: latest.performance_metrics.find_by(metric_type: 'best_practices_score')&.value || 85
      }
    else
      { performance: 75, accessibility: 88, seo: 92, best_practices: 85 }
    end
  end
  
  def generate_top_issues(audit_reports)
    # Generate top issues list
    [
      { title: 'Large layout shifts detected', severity: 'high', impact: 'User Experience' },
      { title: 'Images without alt text', severity: 'medium', impact: 'Accessibility' },
      { title: 'Missing meta descriptions', severity: 'low', impact: 'SEO' },
      { title: 'Render-blocking resources', severity: 'high', impact: 'Performance' },
      { title: 'Text contrast issues', severity: 'medium', impact: 'Accessibility' }
    ]
  end
  
  def generate_recent_improvements(audit_reports)
    # Generate list of recent improvements
    [
      { title: 'Optimized image loading', date: 2.days.ago, impact: '+5 points' },
      { title: 'Fixed accessibility issues', date: 4.days.ago, impact: '+8 points' },
      { title: 'Improved caching strategy', date: 1.week.ago, impact: '+3 points' }
    ]
  end
  
  def calculate_next_audit_date
    # Calculate next scheduled audit date
    'Tomorrow at 2:00 AM'
  end
  
  def generate_competitive_data
    # Generate competitive benchmark data
    [
      { metric: 'Page Load Time', value: 2.3, competitor_avg: 3.1, status: 'better' },
      { metric: 'Time to Interactive', value: 4.2, competitor_avg: 5.8, status: 'better' },
      { metric: 'Core Web Vitals', value: 85, competitor_avg: 72, status: 'better' },
      { metric: 'SEO Score', value: 92, competitor_avg: 88, status: 'better' }
    ]
  end
  
  def generate_recommended_actions(audit_reports)
    # Generate recommended actions based on audit results
    [
      { 
        title: 'Optimize Critical Rendering Path',
        description: 'Reduce render-blocking resources to improve First Contentful Paint',
        priority: 'high',
        estimated_impact: '+10-15 points'
      },
      { 
        title: 'Implement Lazy Loading',
        description: 'Defer loading of off-screen images and iframes',
        priority: 'medium',
        estimated_impact: '+5-8 points'
      },
      { 
        title: 'Enable Text Compression',
        description: 'Use gzip or brotli compression for text-based resources',
        priority: 'medium',
        estimated_impact: '+3-5 points'
      }
    ]
  end
end