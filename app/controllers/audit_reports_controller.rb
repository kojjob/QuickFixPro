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
    @insights = @audit_report.analysis_data['insights'] || []
    @scores = @audit_report.analysis_data['scores'] || {}
    
    # Generate optimization recommendations if available
    @recommendations = @audit_report.optimization_recommendations.order(:priority, :created_at) || []
    
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
    @audits = @website.audit_reports.where(id: @audit_ids).order('audit_reports.created_at DESC')
    
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
                      .where('audit_reports.created_at > ?', 30.days.ago)
                      .order('audit_reports.created_at ASC')
    
    {
      overall_scores: reports.pluck('audit_reports.created_at', 'audit_reports.overall_score'),
      lcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'lcp' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value'),
      fcp_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'fcp' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value'),
      cls_trends: reports.joins(:performance_metrics)
                        .where(performance_metrics: { metric_type: 'cls' })
                        .pluck('audit_reports.created_at', 'performance_metrics.value')
    }
  end
  
  def generate_comparison_data(audits)
    data = {}
    
    # Compare overall scores
    data[:overall_scores] = audits.map { |a| [a.created_at, a.overall_score] }
    
    # Compare Core Web Vitals
    metric_types = ['lcp', 'fcp', 'cls']
    
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
      csv << ['Metric Type', 'Value', 'Unit', 'Category']
      
      audit_report.performance_metrics.each do |metric|
        category = metric.metadata['category'] if metric.metadata.is_a?(Hash)
        csv << [metric.metric_type, metric.value, metric.unit, category]
      end
    end
  end
end