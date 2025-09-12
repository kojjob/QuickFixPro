class Api::V1::PerformanceMetricsController < Api::V1::BaseController
  before_action :set_website
  
  def index
    metrics = performance_metrics_scope
    
    # Apply filters
    metrics = apply_filters(metrics)
    
    # Apply date range filtering
    metrics = apply_date_range(metrics)
    
    # Paginate unless specifically requesting summary data
    if params[:summary] == 'true'
      render_metrics_summary(metrics)
    else
      result = paginate_collection(metrics.includes(:audit_report))
      
      render_success({
        performance_metrics: performance_metrics_json(result[:collection]),
        core_web_vitals: core_web_vitals_json(result[:collection]),
        other_metrics: other_metrics_json(result[:collection]),
        summary: metrics_summary(result[:collection]),
        pagination: result[:pagination]
      })
    end
  end

  def trends
    metrics = performance_metrics_scope
    
    # Apply metric type filter if specified
    if params[:metric_type].present?
      metrics = metrics.where(metric_type: params[:metric_type])
    end
    
    # Apply date range (default to last 30 days)
    from_date = params[:from_date]&.to_date || 30.days.ago.to_date
    to_date = params[:to_date]&.to_date || Date.current
    
    metrics = metrics.joins(:audit_report)
                     .where('audit_reports.created_at >= ? AND audit_reports.created_at <= ?', 
                            from_date.beginning_of_day, to_date.end_of_day)
                     .includes(:audit_report)
                     .order('audit_reports.created_at ASC')
    
    trends_data = build_trends_data(metrics)
    analysis_data = build_trends_analysis(trends_data)
    
    render_success({
      trends: trends_data,
      analysis: analysis_data,
      period: {
        from: from_date.to_s,
        to: to_date.to_s
      }
    })
  end

  def summary
    metrics = performance_metrics_scope
    render_metrics_summary(metrics)
  end

  private

  def set_website
    @website = authorize_website_access!(params[:website_id])
    return false unless @website
  end

  def performance_metrics_scope
    scoped_to_current_account(PerformanceMetric)
      .where(website: @website)
      .includes(:audit_report)
  end

  def apply_filters(metrics)
    metrics = metrics.where(metric_type: params[:metric_type]) if params[:metric_type].present?
    metrics = metrics.where(threshold_status: params[:threshold_status]) if params[:threshold_status].present?
    
    if params[:core_web_vitals_only] == 'true'
      metrics = metrics.core_web_vitals
    end
    
    metrics
  end

  def apply_date_range(metrics)
    if params[:from_date].present? || params[:to_date].present?
      from_date = params[:from_date]&.to_date || 1.year.ago.to_date
      to_date = params[:to_date]&.to_date || Date.current
      
      metrics = metrics.joins(:audit_report)
                       .where('audit_reports.created_at >= ? AND audit_reports.created_at <= ?',
                              from_date.beginning_of_day, to_date.end_of_day)
    end
    
    metrics
  end

  def render_metrics_summary(metrics)
    total_metrics = metrics.count
    
    if total_metrics == 0
      render_success({
        summary: {
          total_metrics: 0,
          good_metrics: 0,
          needs_improvement_metrics: 0,
          poor_metrics: 0,
          average_score_impact: 0
        },
        grade_distribution: { good: 0, needs_improvement: 0, poor: 0 },
        core_web_vitals_status: {},
        recommendations: ['No performance data available']
      })
      return
    end
    
    summary = calculate_metrics_summary(metrics)
    grade_distribution = calculate_grade_distribution(metrics)
    cwv_status = calculate_core_web_vitals_status(metrics)
    recommendations = generate_recommendations(metrics)
    
    render_success({
      summary: summary,
      grade_distribution: grade_distribution,
      core_web_vitals_status: cwv_status,
      recommendations: recommendations
    })
  end

  def calculate_metrics_summary(metrics)
    good_count = metrics.good_performance.count
    improvement_count = metrics.where(threshold_status: :needs_improvement).count
    poor_count = metrics.poor_performance.count
    
    avg_score = metrics.average(:score_contribution) || 0
    
    {
      total_metrics: metrics.count,
      good_metrics: good_count,
      needs_improvement_metrics: improvement_count,
      poor_metrics: poor_count,
      average_score_impact: avg_score.round(2)
    }
  end

  def calculate_grade_distribution(metrics)
    total = metrics.count.to_f
    return { good: 0, needs_improvement: 0, poor: 0 } if total == 0
    
    good_percentage = (metrics.good_performance.count / total * 100).round(1)
    improvement_percentage = (metrics.where(threshold_status: :needs_improvement).count / total * 100).round(1)
    poor_percentage = (metrics.poor_performance.count / total * 100).round(1)
    
    {
      good: good_percentage,
      needs_improvement: improvement_percentage,
      poor: poor_percentage
    }
  end

  def calculate_core_web_vitals_status(metrics)
    cwv_metrics = metrics.core_web_vitals.group_by(&:metric_type)
    
    status = {}
    %w[lcp fid cls].each do |metric_type|
      latest_metric = cwv_metrics[metric_type]&.last
      if latest_metric
        status[metric_type] = {
          value: latest_metric.value,
          status: latest_metric.threshold_status,
          display_value: latest_metric.display_value
        }
      end
    end
    
    # Calculate overall Core Web Vitals status
    all_good = status.values.all? { |s| s[:status] == 'good' }
    any_poor = status.values.any? { |s| s[:status] == 'poor' }
    
    overall_status = if all_good
                      'good'
                    elsif any_poor
                      'poor'
                    else
                      'needs_improvement'
                    end
    
    status.merge(overall_status: overall_status)
  end

  def generate_recommendations(metrics)
    recommendations = []
    
    poor_lcp = metrics.where(metric_type: 'lcp', threshold_status: 'poor').exists?
    poor_fid = metrics.where(metric_type: 'fid', threshold_status: 'poor').exists?
    poor_cls = metrics.where(metric_type: 'cls', threshold_status: 'poor').exists?
    
    recommendations << 'Optimize images and server response times to improve LCP' if poor_lcp
    recommendations << 'Reduce JavaScript execution time to improve FID' if poor_fid
    recommendations << 'Ensure page elements have set dimensions to improve CLS' if poor_cls
    
    recommendations << 'Great job! All metrics are performing well' if recommendations.empty?
    
    recommendations
  end

  def build_trends_data(metrics)
    trends = {}
    
    metrics.group_by(&:metric_type).each do |metric_type, type_metrics|
      trends[metric_type] = type_metrics.map do |metric|
        {
          date: metric.audit_report.created_at.to_date.to_s,
          value: metric.value,
          threshold_status: metric.threshold_status,
          display_value: metric.display_value
        }
      end
    end
    
    trends
  end

  def build_trends_analysis(trends_data)
    analysis = {}
    
    trends_data.each do |metric_type, data_points|
      next if data_points.length < 2
      
      values = data_points.map { |dp| dp[:value] }
      first_value = values.first
      last_value = values.last
      
      trend_direction = if last_value < first_value
                         'improving'
                       elsif last_value > first_value
                         'degrading'
                       else
                         'stable'
                       end
      
      improvement_percentage = if first_value > 0
                                ((first_value - last_value) / first_value * 100).round(1)
                              else
                                0
                              end
      
      analysis[metric_type] = {
        trend_direction: trend_direction,
        improvement_percentage: improvement_percentage,
        average_value: (values.sum / values.length.to_f).round(2),
        data_points_count: values.length
      }
    end
    
    analysis
  end

  def performance_metrics_json(metrics)
    metrics.map { |metric| performance_metric_json(metric) }
  end

  def core_web_vitals_json(metrics)
    metrics.core_web_vitals.map { |metric| performance_metric_json(metric) }
  end

  def other_metrics_json(metrics)
    metrics.where.not(metric_type: %w[lcp fid cls]).map { |metric| performance_metric_json(metric) }
  end

  def metrics_summary(metrics)
    {
      total_metrics: metrics.count,
      good_metrics: metrics.count { |m| m.threshold_status == 'good' },
      needs_improvement_metrics: metrics.count { |m| m.threshold_status == 'needs_improvement' },
      poor_metrics: metrics.count { |m| m.threshold_status == 'poor' },
      average_score_impact: metrics.map(&:score_contribution).compact.sum / [metrics.count, 1].max
    }
  end

  def performance_metric_json(metric)
    {
      id: metric.id,
      metric_type: metric.metric_type,
      value: metric.value,
      unit: metric.unit,
      threshold_status: metric.threshold_status,
      display_name: metric.display_name,
      display_value: metric.display_value,
      threshold_color: metric.threshold_color,
      is_core_web_vital: metric.is_core_web_vital?,
      threshold_good: metric.threshold_good,
      threshold_poor: metric.threshold_poor,
      score_contribution: metric.score_contribution,
      created_at: metric.created_at
    }
  end
end