class DashboardController < ApplicationController
  layout 'dashboard'
  before_action :authenticate_user!
  
  def index
    @account = current_account
    @websites = scoped_to_account(Website).includes(:latest_audit_report)
    
    # Dashboard metrics
    @total_websites = @websites.count
    @active_websites = @websites.active.count
    @recent_audits = scoped_to_account(AuditReport).completed.recent.limit(5)
    @average_score = calculate_average_score
    
    # Usage statistics
    @current_usage = calculate_current_usage
    @usage_limits = current_account.current_subscription&.plan_limits || {}
    
    # Performance trends (last 30 days)
    @performance_trends = calculate_performance_trends
    
    # Recent activity
    @recent_activity = gather_recent_activity
    
    # Critical recommendations for dashboard
    @critical_recommendations = scoped_to_account(OptimizationRecommendation)
                                  .where(priority: :critical, status: :pending)
                                  .includes(:website, :audit_report)
                                  .limit(10)
    
    respond_to do |format|
      format.html
      format.json { render json: dashboard_data }
    end
  end
  
  def metrics
    # Real-time metrics endpoint for Turbo Stream updates
    @websites = scoped_to_account(Website).includes(:latest_audit_report, :performance_metrics)
    @metrics = {
      total_audits: scoped_to_account(AuditReport).count,
      completed_audits: scoped_to_account(AuditReport).completed.count,
      average_performance_score: calculate_average_score,
      total_recommendations: scoped_to_account(OptimizationRecommendation).count,
      critical_issues: scoped_to_account(OptimizationRecommendation).where(priority: :critical, status: :pending).count
    }
    
    respond_to do |format|
      format.json { render json: @metrics }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace('dashboard-metrics', partial: 'dashboard/metrics', locals: { metrics: @metrics }),
          turbo_stream.replace('website-list', partial: 'dashboard/website_list', locals: { websites: @websites })
        ]
      end
    end
  end
  
  def performance_overview
    @websites = scoped_to_account(Website).includes(:performance_metrics, :latest_audit_report)
    @core_web_vitals = calculate_core_web_vitals_summary
    
    respond_to do |format|
      format.json { render json: { websites: @websites.as_json(include: :performance_metrics), core_web_vitals: @core_web_vitals } }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('performance-overview', 
          partial: 'dashboard/performance_overview', 
          locals: { websites: @websites, core_web_vitals: @core_web_vitals }
        )
      end
    end
  end
  
  def usage_stats
    subscription = current_account.current_subscription
    return head :not_found unless subscription
    
    @usage_data = {
      websites: {
        current: scoped_to_account(Website).count,
        limit: subscription.usage_limit_for('websites'),
        percentage: subscription.usage_percentage_for('websites')
      },
      monthly_audits: {
        current: subscription.current_usage_for('monthly_audits'),
        limit: subscription.usage_limit_for('monthly_audits'),
        percentage: subscription.usage_percentage_for('monthly_audits')
      },
      users: {
        current: scoped_to_account(User).count,
        limit: subscription.usage_limit_for('users'),
        percentage: subscription.usage_percentage_for('users')
      }
    }
    
    respond_to do |format|
      format.json { render json: @usage_data }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('usage-stats', 
          partial: 'dashboard/usage_stats', 
          locals: { usage_data: @usage_data }
        )
      end
    end
  end
  
  def alerts
    @critical_recommendations = scoped_to_account(OptimizationRecommendation)
                                  .where(priority: :critical, status: :pending)
                                  .includes(:website, :audit_report)
                                  .limit(10)
    
    @failing_websites = @websites.joins(:latest_audit_report)
                                 .where(audit_reports: { overall_score: ...50 })
                                 .limit(5)
    
    @trial_expiring = current_account.trial? && current_account.days_until_trial_expires <= 7
    @usage_warnings = check_usage_warnings
    
    respond_to do |format|
      format.json do 
        render json: {
          critical_recommendations: @critical_recommendations.count,
          failing_websites: @failing_websites.count,
          trial_expiring: @trial_expiring,
          usage_warnings: @usage_warnings.any?
        }
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace('alerts-panel', 
          partial: 'dashboard/alerts', 
          locals: { 
            critical_recommendations: @critical_recommendations,
            failing_websites: @failing_websites,
            trial_expiring: @trial_expiring,
            usage_warnings: @usage_warnings
          }
        )
      end
    end
  end
  
  private
  
  def dashboard_data
    {
      account: current_account.as_json(only: [:name, :status, :created_at]),
      websites: @websites.as_json(include: :latest_audit_report),
      metrics: {
        total_websites: @total_websites,
        active_websites: @active_websites,
        average_score: @average_score,
        recent_audits_count: @recent_audits.count
      },
      usage: @current_usage,
      limits: @usage_limits,
      trends: @performance_trends,
      activity: @recent_activity
    }
  end
  
  def calculate_average_score
    completed_audits = scoped_to_account(AuditReport).completed.where('overall_score IS NOT NULL')
    return 0 if completed_audits.empty?
    
    (completed_audits.average(:overall_score) || 0).round(1)
  end
  
  def calculate_current_usage
    subscription = current_account.current_subscription
    return {} unless subscription
    
    {
      websites: scoped_to_account(Website).count,
      monthly_audits: subscription.current_usage_for('monthly_audits'),
      users: scoped_to_account(User).count,
      api_requests: subscription.current_usage_for('api_requests')
    }
  end
  
  def calculate_performance_trends
    # Get performance data for the last 30 days
    thirty_days_ago = 30.days.ago
    audit_reports = scoped_to_account(AuditReport)
                      .completed
                      .where(completed_at: thirty_days_ago..Time.current)
                      .where.not(overall_score: nil)
    
    # Group by day manually and calculate average scores
    daily_scores = {}
    
    # Generate dates for the last 30 days
    (0..29).each do |days_ago|
      date = Date.today - days_ago.days
      daily_scores[date.to_s] = 0
    end
    
    # Group reports by date and calculate averages
    audit_reports.each do |report|
      date_key = report.completed_at.to_date.to_s
      if daily_scores[date_key]
        # Track sum and count for averaging
        if daily_scores[date_key] == 0
          daily_scores[date_key] = { sum: report.overall_score, count: 1 }
        else
          if daily_scores[date_key].is_a?(Hash)
            daily_scores[date_key][:sum] += report.overall_score
            daily_scores[date_key][:count] += 1
          end
        end
      end
    end
    
    # Calculate averages and format for charting
    daily_scores.map do |date, value|
      score = if value.is_a?(Hash) && value[:count] > 0
                (value[:sum].to_f / value[:count]).round(1)
              else
                0
              end
      { date: date, score: score }
    end.sort_by { |item| item[:date] }
  end
  
  def gather_recent_activity
    activities = []
    
    # Recent audit completions
    scoped_to_account(AuditReport).completed.recent.limit(5).each do |audit|
      activities << {
        type: 'audit_completed',
        message: "Performance audit completed for #{audit.website.name}",
        timestamp: audit.completed_at,
        score: audit.overall_score,
        website: audit.website.name,
        url: website_audit_report_path(audit.website, audit)
      }
    end
    
    # Recent website additions
    scoped_to_account(Website).recent.limit(3).each do |website|
      activities << {
        type: 'website_added',
        message: "New website added: #{website.name}",
        timestamp: website.created_at,
        website: website.name,
        url: website_path(website)
      }
    end
    
    # Recent critical recommendations
    scoped_to_account(OptimizationRecommendation)
      .where(priority: :critical)
      .order(created_at: :desc)
      .limit(3)
      .each do |recommendation|
      activities << {
        type: 'critical_issue',
        message: "Critical issue found: #{recommendation.title}",
        timestamp: recommendation.created_at,
        website: recommendation.website.name,
        priority: recommendation.priority,
        url: website_optimization_recommendation_path(recommendation.website, recommendation)
      }
    end
    
    # Sort by timestamp and return latest 10
    activities.sort_by { |a| a[:timestamp] }.reverse.first(10)
  end
  
  def calculate_core_web_vitals_summary
    metrics = scoped_to_account(PerformanceMetric)
                .joins(:audit_report)
                .where(audit_reports: { status: :completed })
                .where(metric_type: ['lcp', 'fid', 'cls'])
                .group(:metric_type)
                .average(:value)
    
    summary = {}
    ['lcp', 'fid', 'cls'].each do |metric_type|
      avg_value = metrics[metric_type] || 0
      threshold_status = PerformanceMetric.threshold_status(metric_type, avg_value)
      
      summary[metric_type] = {
        average_value: avg_value.round(metric_type == 'cls' ? 3 : 0),
        status: threshold_status,
        name: PerformanceMetric::THRESHOLDS[metric_type][:name],
        unit: PerformanceMetric::THRESHOLDS[metric_type][:unit]
      }
    end
    
    summary
  end
  
  def check_usage_warnings
    return [] unless current_account.current_subscription
    
    warnings = []
    subscription = current_account.current_subscription
    
    # Check each usage type
    %w[websites monthly_audits users api_requests].each do |feature|
      percentage = subscription.usage_percentage_for(feature)
      
      if percentage >= 90
        warnings << {
          feature: feature,
          percentage: percentage,
          severity: 'critical'
        }
      elsif percentage >= 75
        warnings << {
          feature: feature,
          percentage: percentage,
          severity: 'warning'
        }
      end
    end
    
    warnings
  end
end