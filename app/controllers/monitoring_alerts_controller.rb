class MonitoringAlertsController < ApplicationController
  before_action :set_website
  before_action :set_alert, only: [:show, :acknowledge, :resolve, :dismiss]
  
  def index
    @alerts = @website.monitoring_alerts.includes(:website)
    
    # Filter by status
    @alerts = @alerts.where(status: params[:status]) if params[:status].present?
    
    # Filter by severity
    @alerts = @alerts.where(severity: params[:severity]) if params[:severity].present?
    
    # Filter by date range
    if params[:date_from].present? && params[:date_to].present?
      @alerts = @alerts.where(triggered_at: params[:date_from]..params[:date_to])
    end
    
    @alerts = @alerts.order(triggered_at: :desc).page(params[:page])
    
    # Statistics
    @alert_stats = {
      total: @website.monitoring_alerts.count,
      active: @website.monitoring_alerts.active.count,
      critical: @website.monitoring_alerts.critical.count,
      high: @website.monitoring_alerts.high.count,
      medium: @website.monitoring_alerts.medium.count,
      low: @website.monitoring_alerts.low.count
    }
    
    respond_to do |format|
      format.html
      format.json { render json: @alerts }
      format.turbo_stream if params[:turbo_frame].present?
    end
  end
  
  def show
    @related_audit = AuditReport.find_by(id: @alert.alert_data['audit_report_id']) if @alert.alert_data['audit_report_id']
    @related_alerts = @website.monitoring_alerts
                              .where.not(id: @alert.id)
                              .where(alert_type: @alert.alert_type)
                              .order(triggered_at: :desc)
                              .limit(5)
  end
  
  def acknowledge
    if @alert.update(
      status: 'acknowledged',
      acknowledged_at: Time.current,
      acknowledged_by: Current.user.id,
      alert_data: @alert.alert_data.merge('acknowledged_by_name' => Current.user.full_name)
    )
      respond_to do |format|
        format.html { redirect_to [@website, @alert], notice: 'Alert acknowledged.' }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "alert_#{@alert.id}",
            partial: 'monitoring_alerts/alert',
            locals: { alert: @alert }
          )
        end
        format.json { render json: @alert }
      end
    else
      respond_to do |format|
        format.html { redirect_to [@website, @alert], alert: 'Could not acknowledge alert.' }
        format.json { render json: @alert.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def resolve
    resolution_notes = params[:resolution_notes]
    
    if @alert.update(
      status: 'resolved',
      resolved_at: Time.current,
      resolved_by: Current.user.id,
      alert_data: @alert.alert_data.merge(
        'resolved_by_name' => Current.user.full_name,
        'resolution_notes' => resolution_notes
      )
    )
      # Dismiss related alerts if requested
      if params[:dismiss_related] == 'true'
        @website.monitoring_alerts
                .active
                .where(alert_type: @alert.alert_type)
                .where('triggered_at < ?', @alert.triggered_at)
                .update_all(
                  status: 'dismissed',
                  alert_data: { 'dismissed_with_resolution' => @alert.id }
                )
      end
      
      respond_to do |format|
        format.html { redirect_to website_monitoring_alerts_path(@website), notice: 'Alert resolved successfully.' }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "alert_#{@alert.id}",
              partial: 'monitoring_alerts/alert',
              locals: { alert: @alert }
            ),
            turbo_stream.update(
              "alert_stats",
              partial: 'monitoring_alerts/stats',
              locals: { alert_stats: recalculate_stats }
            )
          ]
        end
        format.json { render json: @alert }
      end
    else
      respond_to do |format|
        format.html { redirect_to [@website, @alert], alert: 'Could not resolve alert.' }
        format.json { render json: @alert.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def dismiss
    if @alert.update(status: 'dismissed', alert_data: @alert.alert_data.merge('dismissed_by' => Current.user.id))
      respond_to do |format|
        format.html { redirect_to website_monitoring_alerts_path(@website), notice: 'Alert dismissed.' }
        format.turbo_stream do
          render turbo_stream: turbo_stream.remove("alert_#{@alert.id}")
        end
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html { redirect_to [@website, @alert], alert: 'Could not dismiss alert.' }
        format.json { render json: @alert.errors, status: :unprocessable_entity }
      end
    end
  end
  
  # Bulk actions
  def bulk_acknowledge
    alert_ids = params[:alert_ids] || []
    alerts = @website.monitoring_alerts.where(id: alert_ids, status: 'active')
    
    updated_count = alerts.update_all(
      status: 'acknowledged',
      acknowledged_at: Time.current,
      acknowledged_by: Current.user.id
    )
    
    respond_to do |format|
      format.html do
        redirect_to website_monitoring_alerts_path(@website), 
                    notice: "#{updated_count} alerts acknowledged."
      end
      format.json { render json: { updated: updated_count } }
    end
  end
  
  def bulk_dismiss
    alert_ids = params[:alert_ids] || []
    alerts = @website.monitoring_alerts.where(id: alert_ids).where.not(status: 'resolved')
    
    updated_count = alerts.update_all(status: 'dismissed')
    
    respond_to do |format|
      format.html do
        redirect_to website_monitoring_alerts_path(@website), 
                    notice: "#{updated_count} alerts dismissed."
      end
      format.json { render json: { updated: updated_count } }
    end
  end
  
  private
  
  def set_website
    @website = Current.account.websites.find(params[:website_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to websites_path, alert: 'Website not found.'
  end
  
  def set_alert
    @alert = @website.monitoring_alerts.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to website_monitoring_alerts_path(@website), alert: 'Alert not found.'
  end
  
  def recalculate_stats
    {
      total: @website.monitoring_alerts.count,
      active: @website.monitoring_alerts.active.count,
      critical: @website.monitoring_alerts.critical.count,
      high: @website.monitoring_alerts.high.count,
      medium: @website.monitoring_alerts.medium.count,
      low: @website.monitoring_alerts.low.count
    }
  end
end