class AuditReportsController < ApplicationController
  before_action :set_website
  before_action :set_audit_report, only: [:show, :performance_details, :optimization_suggestions, :export]
  
  def index
    @audit_reports = @website.audit_reports
                            .includes(:performance_metrics)
                            .order(created_at: :desc)
                            .page(params[:page])
    
    # Performance trends
    @performance_trends = calculate_performance_trends
    
    respond_to do |format|
      format.html
      format.json { render json: @audit_reports }
    end
  end
  
  def show
    @performance_metrics = @audit_report.performance_metrics.by_category
    @core_web_vitals = @audit_report.performance_metrics.core_web_vitals
    @insights = @audit_report.analysis_data['insights'] || []
    @scores = @audit_report.analysis_data['scores'] || {}
    
    # Generate optimization suggestions if not cached
    if @audit_report.optimization_suggestions.blank?
      suggestions = OptimizationSuggesterService.call(@audit_report)
      if suggestions.success?
        @audit_report.update(optimization_suggestions: suggestions.data)
      end
    end
    
    @suggestions = @audit_report.optimization_suggestions || {}
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
    @audits = @website.audit_reports.where(id: @audit_ids).order(created_at: :desc)
    
    if @audits.count < 2
      redirect_to website_audit_reports_path(@website), 
                  alert: 'Please select at least 2 audits to compare.'
      return
    end
    
    @comparison_data = generate_comparison_data(@audits)
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
                      .where('created_at > ?', 30.days.ago)
                      .order(created_at: :asc)
    
    {
      overall_scores: reports.pluck(:created_at, :overall_score),
      lcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_name: 'largest_contentful_paint' })
                        .pluck(:created_at, 'performance_metrics.metric_value'),
      fcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_name: 'first_contentful_paint' })
                        .pluck(:created_at, 'performance_metrics.metric_value'),
      cls_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_name: 'cumulative_layout_shift' })
                        .pluck(:created_at, 'performance_metrics.metric_value')
    }
  end
  
  def generate_comparison_data(audits)
    data = {}
    
    # Compare overall scores
    data[:overall_scores] = audits.map { |a| [a.created_at, a.overall_score] }
    
    # Compare Core Web Vitals
    metric_names = ['largest_contentful_paint', 'first_contentful_paint', 'cumulative_layout_shift']
    
    metric_names.each do |metric|
      data[metric.to_sym] = audits.map do |audit|
        value = audit.performance_metrics.find_by(metric_name: metric)&.metric_value
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
        csv << [metric.metric_name, metric.metric_value, metric.unit, metric.category]
      end
    end
  end
end