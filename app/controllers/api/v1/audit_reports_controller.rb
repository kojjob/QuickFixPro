class Api::V1::AuditReportsController < Api::V1::BaseController
  before_action :set_website
  before_action :set_audit_report, only: [:show, :destroy]
  before_action :check_trigger_permissions!, only: [:create]
  before_action :check_cancel_permissions!, only: [:destroy]

  def index
    audit_reports = @website.audit_reports.recent
    
    # Apply filters
    audit_reports = audit_reports.where(status: params[:status]) if params[:status].present?
    
    if params[:min_score].present?
      audit_reports = audit_reports.where('overall_score >= ?', params[:min_score])
    end
    
    if params[:max_score].present?
      audit_reports = audit_reports.where('overall_score <= ?', params[:max_score])
    end
    
    # Paginate
    result = paginate_collection(audit_reports)
    
    render_success({
      audit_reports: audit_reports_json(result[:collection]),
      pagination: result[:pagination]
    })
  end

  def show
    render_success({
      audit_report: audit_report_json(@audit_report, detailed: true)
    })
  end

  def create
    return unless check_usage_limit!(:audit_reports)
    
    # Check for existing pending/running audit
    if @website.audit_reports.where(status: [:pending, :running]).exists?
      render_conflict('Audit already in progress')
      return
    end
    
    @audit_report = @website.audit_reports.build(audit_report_params)
    @audit_report.triggered_by = current_user
    @audit_report.status = :pending
    
    if @audit_report.save
      # Enqueue audit processing job (assuming you have one)
      # AuditProcessingJob.perform_later(@audit_report)
      
      render_created({
        audit_report: audit_report_json(@audit_report)
      })
    else
      render_validation_errors(ActiveRecord::RecordInvalid.new(@audit_report))
    end
  end

  def destroy
    # Can only cancel pending audits
    unless @audit_report.pending?
      render_conflict('Cannot cancel completed audit')
      return
    end
    
    @audit_report.update!(status: :cancelled)
    render_no_content
  end

  private

  def set_website
    @website = authorize_website_access!(params[:website_id])
    return false unless @website
  end

  def set_audit_report
    @audit_report = @website.audit_reports.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_not_found('Audit report not found')
    false
  end

  def check_trigger_permissions!
    check_user_permissions!(:trigger_audits)
  end

  def check_cancel_permissions!
    # Only admins and owners can cancel audits
    unless current_user.can_manage_account?
      render_insufficient_permissions
      return false
    end
    true
  end

  def audit_report_params
    permitted = params.require(:audit_report).permit(:audit_type) rescue {}
    permitted[:audit_type] ||= 'manual'
    permitted
  end

  def audit_reports_json(audit_reports)
    audit_reports.map { |report| audit_report_json(report) }
  end

  def audit_report_json(audit_report, detailed: false)
    base_attributes = {
      id: audit_report.id,
      website_id: audit_report.website_id,
      overall_score: audit_report.overall_score,
      audit_type: audit_report.audit_type,
      status: audit_report.status,
      started_at: audit_report.started_at,
      completed_at: audit_report.completed_at,
      duration: audit_report.duration,
      performance_grade: audit_report.performance_grade,
      performance_color: audit_report.performance_color,
      created_at: audit_report.created_at,
      updated_at: audit_report.updated_at
    }

    if detailed
      base_attributes.merge({
        triggered_by_id: audit_report.triggered_by_id,
        raw_results: audit_report.raw_results,
        summary_data: audit_report.summary_data,
        error_message: audit_report.error_message,
        performance_metrics: performance_metrics_json(audit_report.performance_metrics),
        core_web_vitals: performance_metrics_json(audit_report.core_web_vitals),
        recommendations_count: audit_report.optimization_recommendations.count,
        has_recommendations: audit_report.has_recommendations?
      })
    else
      base_attributes
    end
  end

  def performance_metrics_json(metrics)
    metrics.map do |metric|
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
end