class AnalyticsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_date_range
  before_action :load_websites
  
  def index
    @overview_stats = calculate_overview_stats
    @performance_summary = calculate_performance_summary
    @recent_audits = recent_audits
    @top_performing_websites = top_performing_websites
    @websites_needing_attention = websites_needing_attention
    
    respond_to do |format|
      format.html
      format.json { render json: analytics_data }
    end
  end
  
  def performance
    @website = Current.account.websites.find(params[:website_id]) if params[:website_id].present?
    
    if @website
      @performance_data = website_performance_data(@website)
      @core_web_vitals = website_core_web_vitals(@website)
      @performance_history = website_performance_history(@website)
    else
      @aggregate_performance = aggregate_performance_data
      @websites_performance = websites_performance_comparison
    end
    
    respond_to do |format|
      format.html
      format.json { render json: @website ? @performance_data : @aggregate_performance }
    end
  end
  
  def trends
    @trend_data = {
      overall_scores: overall_score_trends,
      core_web_vitals: core_web_vitals_trends,
      audit_frequency: audit_frequency_trends,
      improvement_rate: improvement_rate_trends
    }
    
    @insights = generate_trend_insights(@trend_data)
    
    respond_to do |format|
      format.html
      format.json { render json: @trend_data }
    end
  end
  
  def comparisons
    @websites = Current.account.websites.active
    @comparison_metrics = params[:metrics] || ['overall_score', 'lcp', 'fcp', 'cls']
    
    @comparison_data = generate_comparison_data(@websites, @comparison_metrics)
    @benchmarks = industry_benchmarks
    
    respond_to do |format|
      format.html
      format.json { render json: @comparison_data }
    end
  end
  
  def export
    format = params[:format_type] || 'csv'
    
    case format
    when 'csv'
      send_data generate_csv_report, 
                filename: "analytics_report_#{Date.current}.csv",
                type: 'text/csv'
    when 'json'
      send_data generate_json_report.to_json,
                filename: "analytics_report_#{Date.current}.json",
                type: 'application/json'
    when 'pdf'
      # This would require a PDF generation service
      redirect_to analytics_path, alert: 'PDF export coming soon!'
    else
      redirect_to analytics_path, alert: 'Invalid export format.'
    end
  end
  
  private
  
  def set_date_range
    @start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    @end_date = params[:end_date]&.to_date || Date.current
  end
  
  def load_websites
    @websites = Current.account.websites.active
  end
  
  def calculate_overview_stats
    {
      total_websites: Current.account.websites.count,
      active_websites: Current.account.websites.active.count,
      total_audits: Current.account.audit_reports
                           .where('audit_reports.created_at': @start_date..@end_date)
                           .count,
      audits_this_month: Current.account.audit_reports
                                .where('audit_reports.created_at > ?', 1.month.ago)
                                .count,
      average_score: Current.account.audit_reports
                           .completed
                           .where('audit_reports.created_at': @start_date..@end_date)
                           .average(:overall_score)&.round(1) || 0,
      improvement_rate: calculate_improvement_rate,
      total_alerts: MonitoringAlert.joins(website: :account)
                          .where(websites: { account_id: Current.account.id })
                          .where(created_at: @start_date..@end_date)
                          .count,
      critical_alerts: MonitoringAlert.joins(website: :account)
                             .where(websites: { account_id: Current.account.id })
                             .critical
                             .where(created_at: @start_date..@end_date)
                             .count
    }
  end
  
  def calculate_performance_summary
    recent_audits = Current.account.audit_reports
                          .completed
                          .includes(:performance_metrics)
                          .where(created_at: @start_date..@end_date)
    
    return {} if recent_audits.empty?
    
    {
      average_lcp: calculate_average_metric(recent_audits, 'largest_contentful_paint'),
      average_fcp: calculate_average_metric(recent_audits, 'first_contentful_paint'),
      average_cls: calculate_average_metric(recent_audits, 'cumulative_layout_shift'),
      average_ttfb: calculate_average_metric(recent_audits, 'time_to_first_byte'),
      passing_cwv: calculate_passing_core_web_vitals(recent_audits)
    }
  end
  
  def calculate_average_metric(audits, metric_name)
    metrics = PerformanceMetric.joins(:audit_report)
                              .where(audit_report: audits)
                              .where(metric_type: metric_name)
    
    return 0 if metrics.empty?
    
    avg = metrics.average(:value)&.to_f || 0
    metric_name.include?('shift') ? avg.round(3) : avg.round(0)
  end
  
  def calculate_passing_core_web_vitals(audits)
    total = audits.count
    return 0 if total == 0
    
    passing = audits.select do |audit|
      lcp = audit.performance_metrics.find_by(metric_type: 'largest_contentful_paint')&.value&.to_f
      fcp = audit.performance_metrics.find_by(metric_type: 'first_contentful_paint')&.value&.to_f
      cls = audit.performance_metrics.find_by(metric_type: 'cumulative_layout_shift')&.value&.to_f
      
      lcp && fcp && cls && lcp < 2500 && fcp < 1800 && cls < 0.1
    end.count
    
    ((passing.to_f / total) * 100).round(1)
  end
  
  def calculate_improvement_rate
    # Compare current period to previous period
    current_avg = Current.account.audit_reports
                        .completed
                        .where(created_at: @start_date..@end_date)
                        .average(:overall_score) || 0
    
    previous_period_start = @start_date - (@end_date - @start_date).days
    previous_avg = Current.account.audit_reports
                         .completed
                         .where(created_at: previous_period_start..@start_date)
                         .average(:overall_score) || 0
    
    return 0 if previous_avg == 0
    
    ((current_avg - previous_avg) / previous_avg * 100).round(1)
  end
  
  def recent_audits
    Current.account.audit_reports
          .completed
          .includes(:website)
          .order('audit_reports.created_at DESC')
          .limit(10)
  end
  
  def top_performing_websites
    Current.account.websites
          .active
          .where('current_score >= ?', 80)
          .order(current_score: :desc)
          .limit(5)
  end
  
  def websites_needing_attention
    Current.account.websites
          .active
          .where('current_score < ?', 50)
          .order(current_score: :asc)
          .limit(5)
  end
  
  def website_performance_data(website)
    audits = website.audit_reports
                   .completed
                   .where(created_at: @start_date..@end_date)
                   .includes(:performance_metrics)
    
    {
      website_name: website.name,
      url: website.url,
      current_score: website.current_score,
      audit_count: audits.count,
      average_score: audits.average(:overall_score)&.round(1) || 0,
      score_trend: calculate_score_trend(audits),
      last_audit: audits.first&.created_at
    }
  end
  
  def website_core_web_vitals(website)
    latest_audit = website.audit_reports.completed.order('audit_reports.created_at DESC').first
    return {} unless latest_audit
    
    {
      lcp: latest_audit.performance_metrics.find_by(metric_type: 'largest_contentful_paint')&.value,
      fcp: latest_audit.performance_metrics.find_by(metric_type: 'first_contentful_paint')&.value,
      cls: latest_audit.performance_metrics.find_by(metric_type: 'cumulative_layout_shift')&.value,
      ttfb: latest_audit.performance_metrics.find_by(metric_type: 'time_to_first_byte')&.value,
      fid: latest_audit.performance_metrics.find_by(metric_type: 'first_input_delay')&.value
    }
  end
  
  def website_performance_history(website)
    website.audit_reports
          .completed
          .where(created_at: @start_date..@end_date)
          .order('audit_reports.created_at ASC')
          .pluck('audit_reports.created_at', 'audit_reports.overall_score')
          .map { |date, score| { date: date, score: score } }
  end
  
  def aggregate_performance_data
    {
      websites_analyzed: @websites.count,
      total_audits: Current.account.audit_reports
                          .where(created_at: @start_date..@end_date)
                          .count,
      average_score: Current.account.audit_reports
                          .completed
                          .where(created_at: @start_date..@end_date)
                          .average(:overall_score)&.round(1) || 0,
      score_distribution: calculate_score_distribution
    }
  end
  
  def calculate_score_distribution
    scores = Current.account.audit_reports
                   .completed
                   .where(created_at: @start_date..@end_date)
                   .pluck(:overall_score)
    
    {
      excellent: scores.count { |s| s >= 90 },
      good: scores.count { |s| s >= 70 && s < 90 },
      needs_improvement: scores.count { |s| s >= 50 && s < 70 },
      poor: scores.count { |s| s < 50 }
    }
  end
  
  def websites_performance_comparison
    @websites.map do |website|
      latest_audit = website.audit_reports.completed.order('audit_reports.created_at DESC').first
      next unless latest_audit
      
      {
        id: website.id,
        name: website.name,
        score: latest_audit.overall_score,
        lcp: latest_audit.performance_metrics.find_by(metric_type: 'largest_contentful_paint')&.value,
        fcp: latest_audit.performance_metrics.find_by(metric_type: 'first_contentful_paint')&.value,
        cls: latest_audit.performance_metrics.find_by(metric_type: 'cumulative_layout_shift')&.value
      }
    end.compact
  end
  
  def overall_score_trends
    reports = Current.account.audit_reports
                    .completed
                    .where(created_at: @start_date..@end_date)
                    .order(:created_at)
    
    # Group by day manually
    grouped = reports.group_by { |r| r.created_at.to_date }
    
    grouped.map do |date, reports|
      scores = reports.map(&:overall_score).compact
      avg_score = scores.any? ? (scores.sum.to_f / scores.size).round(1) : nil
      { date: date, score: avg_score }
    end.sort_by { |h| h[:date] }
  end
  
  def core_web_vitals_trends
    metrics = ['largest_contentful_paint', 'first_contentful_paint', 'cumulative_layout_shift']
    
    trends = {}
    metrics.each do |metric|
      performance_metrics = PerformanceMetric
                          .joins(audit_report: :website)
                          .where(metric_type: metric)
                          .where(websites: { account_id: Current.account.id })
                          .where('performance_metrics.created_at >= ?', @start_date)
                          .where('performance_metrics.created_at <= ?', @end_date)
                          .order('performance_metrics.created_at')
      
      # Group by day manually
      grouped = performance_metrics.group_by { |pm| pm.created_at.to_date }
      
      trends[metric] = grouped.map do |date, metrics|
        values = metrics.map(&:value).compact
        avg_value = values.any? ? (values.sum.to_f / values.size).round(2) : nil
        { date: date, value: avg_value }
      end.sort_by { |h| h[:date] }
    end
    
    trends
  end
  
  def audit_frequency_trends
    reports = Current.account.audit_reports
                    .where(created_at: @start_date..@end_date)
                    .order(:created_at)
    
    # Group by day manually
    grouped = reports.group_by { |r| r.created_at.to_date }
    
    grouped.map do |date, reports|
      { date: date, count: reports.count }
    end.sort_by { |h| h[:date] }
  end
  
  def improvement_rate_trends
    # Calculate week-over-week improvement
    reports = Current.account.audit_reports
                     .completed
                     .where(created_at: @start_date..@end_date)
                     .order(:created_at)
    
    # Group by week manually
    weekly_groups = reports.group_by do |report|
      # Get the start of the week (Monday)
      report.created_at.beginning_of_week
    end
    
    # Calculate average score for each week
    weekly_scores = {}
    weekly_groups.each do |week_start, week_reports|
      scores = week_reports.map(&:overall_score).compact
      if scores.any?
        weekly_scores[week_start] = (scores.sum.to_f / scores.size).round(1)
      end
    end
    
    # Sort by date and calculate improvement rates
    trends = []
    previous_score = nil
    
    weekly_scores.sort_by { |date, _| date }.each do |date, score|
      if previous_score
        improvement = ((score - previous_score) / previous_score * 100).round(1)
        trends << { date: date, improvement: improvement }
      end
      previous_score = score
    end
    
    trends
  end
  
  def generate_trend_insights(trend_data)
    insights = []
    
    # Analyze overall score trends
    if trend_data[:overall_scores].any?
      recent_scores = trend_data[:overall_scores].last(7).map { |d| d[:score] }.compact
      if recent_scores.any?
        avg_recent = recent_scores.sum / recent_scores.size
        insights << "Average score over the last 7 days: #{avg_recent.round(1)}"
      end
    end
    
    # Analyze improvement rate
    if trend_data[:improvement_rate].any?
      latest_improvement = trend_data[:improvement_rate].last[:improvement]
      if latest_improvement > 0
        insights << "Performance improved by #{latest_improvement}% in the last week"
      elsif latest_improvement < 0
        insights << "Performance declined by #{latest_improvement.abs}% in the last week"
      end
    end
    
    insights
  end
  
  def generate_comparison_data(websites, metrics)
    data = {}
    
    websites.each do |website|
      latest_audit = website.audit_reports.completed.order('audit_reports.created_at DESC').first
      next unless latest_audit
      
      data[website.id] = {
        name: website.name,
        url: website.url
      }
      
      metrics.each do |metric|
        if metric == 'overall_score'
          data[website.id][metric] = latest_audit.overall_score
        else
          metric_record = latest_audit.performance_metrics.find_by(metric_type: metric_name_mapping(metric))
          data[website.id][metric] = metric_record&.value
        end
      end
    end
    
    data
  end
  
  def metric_name_mapping(metric)
    {
      'lcp' => 'largest_contentful_paint',
      'fcp' => 'first_contentful_paint',
      'cls' => 'cumulative_layout_shift',
      'ttfb' => 'time_to_first_byte',
      'fid' => 'first_input_delay'
    }[metric] || metric
  end
  
  def industry_benchmarks
    {
      overall_score: { good: 90, needs_improvement: 50 },
      lcp: { good: 2500, needs_improvement: 4000 },
      fcp: { good: 1800, needs_improvement: 3000 },
      cls: { good: 0.1, needs_improvement: 0.25 },
      ttfb: { good: 800, needs_improvement: 1800 }
    }
  end
  
  def calculate_score_trend(audits)
    return 'stable' if audits.count < 2
    
    recent = audits.limit(audits.count / 2)
    older = audits.offset(audits.count / 2)
    
    recent_avg = recent.average(:overall_score) || 0
    older_avg = older.average(:overall_score) || 0
    
    return 'stable' if older_avg == 0
    
    change = ((recent_avg - older_avg) / older_avg * 100).abs
    
    if change < 5
      'stable'
    elsif recent_avg > older_avg
      change > 10 ? 'improving_fast' : 'improving'
    else
      change > 10 ? 'declining_fast' : 'declining'
    end
  end
  
  def analytics_data
    {
      overview: @overview_stats,
      performance: @performance_summary,
      recent_audits: @recent_audits.map { |a| 
        {
          id: a.id,
          website: a.website.name,
          score: a.overall_score,
          created_at: a.created_at
        }
      },
      top_performers: @top_performing_websites.map { |w|
        {
          id: w.id,
          name: w.name,
          score: w.current_score
        }
      },
      needs_attention: @websites_needing_attention.map { |w|
        {
          id: w.id,
          name: w.name,
          score: w.current_score
        }
      }
    }
  end
  
  def generate_csv_report
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Analytics Report', "Generated: #{Time.current}"]
      csv << ['Date Range', "#{@start_date} to #{@end_date}"]
      csv << []
      
      csv << ['Overview Statistics']
      @overview_stats.each do |key, value|
        csv << [key.to_s.humanize, value]
      end
      csv << []
      
      csv << ['Performance Summary']
      @performance_summary.each do |key, value|
        csv << [key.to_s.humanize, value]
      end
      csv << []
      
      csv << ['Website Performance']
      csv << ['Website', 'Current Score', 'Last Audit']
      @websites.each do |website|
        csv << [website.name, website.current_score, website.last_monitored_at]
      end
    end
  end
  
  def generate_json_report
    {
      metadata: {
        generated_at: Time.current,
        date_range: {
          start: @start_date,
          end: @end_date
        }
      },
      overview: @overview_stats,
      performance: @performance_summary,
      websites: @websites.map { |w|
        {
          id: w.id,
          name: w.name,
          url: w.url,
          current_score: w.current_score,
          last_monitored_at: w.last_monitored_at
        }
      }
    }
  end
end