class PerformanceMetricsController < ApplicationController
  before_action :set_website
  before_action :set_performance_metric, only: [:show]
  
  def index
    @metrics = @website.performance_metrics.includes(:audit_report)
    
    # Filter by audit report if specified
    @metrics = @metrics.where(audit_report_id: params[:audit_report_id]) if params[:audit_report_id].present?
    
    # Filter by category
    @metrics = @metrics.where(category: params[:category]) if params[:category].present?
    
    # Filter by metric name
    @metrics = @metrics.where(metric_name: params[:metric_name]) if params[:metric_name].present?
    
    # Date range filter
    if params[:date_from].present? && params[:date_to].present?
      @metrics = @metrics.where(measurement_time: params[:date_from]..params[:date_to])
    end
    
    # Group metrics for better visualization
    @grouped_metrics = {
      core_web_vitals: @metrics.core_web_vitals.group_by(&:metric_name),
      navigation: @metrics.where(category: 'navigation_timing').group_by(&:metric_name),
      resources: @metrics.where(category: 'resources').group_by(&:metric_name),
      lighthouse: @metrics.where(category: 'lighthouse').group_by(&:metric_name)
    }
    
    # Calculate aggregates for time series
    @time_series_data = generate_time_series_data
    
    respond_to do |format|
      format.html
      format.json { render json: @grouped_metrics }
      format.csv { send_data generate_csv, filename: "performance_metrics_#{Date.current}.csv" }
    end
  end
  
  def show
    @historical_values = @website.performance_metrics
                                 .where(metric_name: @metric.metric_name)
                                 .order(measurement_time: :desc)
                                 .limit(30)
    
    @statistics = calculate_statistics(@historical_values)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          metric: @metric,
          historical: @historical_values,
          statistics: @statistics
        }
      end
    end
  end
  
  private
  
  def set_website
    @website = Current.account.websites.find(params[:website_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to websites_path, alert: 'Website not found.'
  end
  
  def set_performance_metric
    @metric = @website.performance_metrics.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to website_performance_metrics_path(@website), alert: 'Performance metric not found.'
  end
  
  def generate_time_series_data
    # Get metrics from the last 30 days
    recent_metrics = @website.performance_metrics
                            .where('measurement_time > ?', 30.days.ago)
                            .order(measurement_time: :asc)
    
    # Core Web Vitals time series
    cwv_metrics = ['largest_contentful_paint', 'first_contentful_paint', 
                   'cumulative_layout_shift', 'time_to_first_byte']
    
    time_series = {}
    
    cwv_metrics.each do |metric_name|
      values = recent_metrics.where(metric_name: metric_name)
                            .pluck(:measurement_time, :metric_value)
      time_series[metric_name] = values if values.any?
    end
    
    time_series
  end
  
  def calculate_statistics(metrics)
    return {} if metrics.empty?
    
    values = metrics.map(&:metric_value).compact.map(&:to_f)
    
    {
      count: values.size,
      min: values.min,
      max: values.max,
      average: values.sum / values.size,
      median: calculate_median(values),
      percentile_95: calculate_percentile(values, 0.95),
      percentile_99: calculate_percentile(values, 0.99),
      std_deviation: calculate_std_deviation(values),
      trend: calculate_trend(metrics)
    }
  end
  
  def calculate_median(values)
    sorted = values.sort
    len = sorted.length
    return 0 if len == 0
    
    if len.odd?
      sorted[len / 2]
    else
      (sorted[len / 2 - 1] + sorted[len / 2]) / 2.0
    end
  end
  
  def calculate_percentile(values, percentile)
    sorted = values.sort
    k = (percentile * (sorted.length - 1)).floor
    f = (percentile * (sorted.length - 1)) % 1
    
    return sorted[k] if f == 0
    sorted[k] + (f * (sorted[k + 1] - sorted[k]))
  end
  
  def calculate_std_deviation(values)
    return 0 if values.empty?
    
    mean = values.sum / values.size.to_f
    sum_of_squared_differences = values.inject(0) { |sum, val| sum + (val - mean) ** 2 }
    Math.sqrt(sum_of_squared_differences / values.size)
  end
  
  def calculate_trend(metrics)
    return 'stable' if metrics.size < 2
    
    recent = metrics.first(metrics.size / 2).map(&:metric_value).compact.map(&:to_f)
    older = metrics.last(metrics.size / 2).map(&:metric_value).compact.map(&:to_f)
    
    return 'stable' if recent.empty? || older.empty?
    
    recent_avg = recent.sum / recent.size
    older_avg = older.sum / older.size
    
    percentage_change = ((recent_avg - older_avg) / older_avg * 100).abs
    
    if percentage_change < 5
      'stable'
    elsif recent_avg > older_avg
      percentage_change > 20 ? 'degrading_fast' : 'degrading'
    else
      percentage_change > 20 ? 'improving_fast' : 'improving'
    end
  end
  
  def generate_csv
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Metric Name', 'Value', 'Unit', 'Category', 'Measurement Time', 'Audit Report ID']
      
      @metrics.each do |metric|
        csv << [
          metric.metric_name,
          metric.metric_value,
          metric.unit,
          metric.category,
          metric.measurement_time,
          metric.audit_report_id
        ]
      end
    end
  end
end