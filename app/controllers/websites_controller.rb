class WebsitesController < ApplicationController
  layout 'dashboard'
  before_action :authenticate_user!
  before_action :ensure_account_context
  before_action :set_website, only: [:show, :edit, :update, :destroy, :monitor, :audit_history]
  before_action :check_website_limit, only: [:new, :create]
  
  def index
    # Temporary pagination workaround
    @websites = current_account.websites.includes(:audit_reports)
                              .order('websites.created_at DESC')
    
    # Manual pagination if Kaminari isn't working
    page = (params[:page] || 1).to_i
    per_page = 25
    offset = (page - 1) * per_page
    
    @websites = @websites.limit(per_page).offset(offset)
    
    @statistics = {
      total_websites: current_account.websites.count,
      active_websites: current_account.websites.active.count,
      total_audits: current_account.audit_reports.count,
      audits_this_month: current_account.audit_reports.where('audit_reports.created_at > ?', 1.month.ago).count
    }
  end
  
  def show
    @latest_audit = @website.audit_reports.completed.order('audit_reports.created_at DESC').first
    @performance_metrics = @latest_audit&.performance_metrics&.recent || []
    @recent_audit_reports = @website.audit_reports.completed
                                   .order('audit_reports.created_at DESC')
                                   .limit(5)
    @monitoring_alerts = @website.monitoring_alerts.active.recent
  end
  
  def new
    @website = current_account.websites.build
  end
  
  def create
    @website = current_account.websites.build(website_params)
    
    if @website.save
      # Queue initial audit
      WebsiteMonitorJob.perform_later(@website.id, triggered_by: 'initial_setup')
      
      redirect_to @website, notice: 'Website was successfully added. Initial audit started.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @website.update(website_params)
      redirect_to @website, notice: 'Website settings were successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @website.destroy
    redirect_to websites_path, notice: 'Website was successfully removed.'
  end
  
  # Custom actions
  
  def monitor
    # Trigger manual monitoring
    result = WebsiteMonitorJob.perform_later(@website.id, triggered_by: 'manual')
    
    respond_to do |format|
      format.html do
        redirect_to @website, notice: 'Monitoring audit started successfully.'
      end
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "website_#{@website.id}_monitor_button",
          partial: 'websites/monitor_button',
          locals: { website: @website, monitoring: true }
        )
      end
    end
  end
  
  def audit_history
    @audits = @website.audit_reports
                      .includes(:performance_metrics)
                      .order('audit_reports.created_at DESC')
                      
    # Manual pagination  
    page = (params[:page] || 1).to_i
    per_page = 25
    offset = (page - 1) * per_page
    
    @audits = @audits.limit(per_page).offset(offset)
    
    respond_to do |format|
      format.html
      format.json do
        render json: @audits.map { |audit|
          {
            id: audit.id,
            status: audit.status,
            overall_score: audit.overall_score,
            created_at: audit.created_at,
            completed_at: audit.completed_at,
            audit_type: audit.audit_type
          }
        }
      end
    end
  end
  
  private
  
  def ensure_account_context
    unless current_account
      redirect_to root_path, alert: 'Please select an account first.'
      return
    end
  end
  
  def set_website
    @website = current_account.websites.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to websites_path, alert: 'Website not found.'
  end
  
  def website_params
    params.require(:website).permit(
      :name, :url, :active, :monitoring_frequency,
      monitoring_settings: [
        :enable_performance_monitoring,
        :enable_seo_monitoring,
        :enable_security_monitoring,
        :enable_accessibility_monitoring,
        :alert_on_critical,
        :alert_on_high,
        :notification_emails
      ]
    )
  end
  
  def check_website_limit
    subscription = current_account.subscription
    return unless subscription
    
    website_limit = subscription.plan_limits['website_limit'] || 10
    current_count = current_account.websites.count
    
    if current_count >= website_limit
      redirect_to websites_path, 
                  alert: "You've reached your website limit (#{website_limit}). Please upgrade your plan to add more websites."
    end
  end
end