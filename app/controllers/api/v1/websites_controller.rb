class Api::V1::WebsitesController < Api::V1::BaseController
  before_action :set_website, only: [:show, :update, :destroy]
  before_action :check_create_permissions!, only: [:create]
  before_action :check_manage_permissions!, only: [:update, :destroy]

  def index
    websites = scoped_to_current_account(Website)
    
    # Apply filters
    websites = websites.where(status: params[:status]) if params[:status].present?
    
    # Apply ordering
    websites = websites.recent
    
    # Paginate
    result = paginate_collection(websites)
    
    render_success({
      websites: websites_json(result[:collection]),
      pagination: result[:pagination]
    })
  end

  def show
    render_success({
      website: website_json(@website, detailed: true)
    })
  end

  def create
    return unless check_usage_limit!(:websites)
    
    @website = build_for_current_account(current_account.websites, website_params)
    @website.created_by = current_user
    
    if @website.save
      render_created({
        website: website_json(@website)
      })
    else
      render_validation_errors(ActiveRecord::RecordInvalid.new(@website))
    end
  end

  def update
    if @website.update(website_params)
      render_success({
        website: website_json(@website)
      })
    else
      render_validation_errors(ActiveRecord::RecordInvalid.new(@website))
    end
  end

  def destroy
    @website.destroy
    render_no_content
  end

  private

  def set_website
    @website = authorize_website_access!(params[:id])
    return false unless @website
  end

  def check_create_permissions!
    check_user_permissions!(:create_websites)
  end

  def check_manage_permissions!
    # Viewers cannot modify websites
    if current_user.viewer?
      render_insufficient_permissions
      return false
    end
    
    # Members cannot delete websites
    if action_name == 'destroy' && current_user.member?
      render_insufficient_permissions
      return false
    end
    
    true
  end

  def website_params
    params.require(:website).permit(:name, :url, :monitoring_frequency)
  end

  def websites_json(websites)
    websites.map { |website| website_json(website) }
  end

  def website_json(website, detailed: false)
    base_attributes = {
      id: website.id,
      name: website.name,
      url: website.url,
      status: website.status,
      monitoring_frequency: website.monitoring_frequency,
      current_score: website.current_score,
      performance_grade: website.performance_grade,
      performance_color: website.performance_color,
      last_monitored_at: website.last_monitored_at,
      created_at: website.created_at,
      updated_at: website.updated_at
    }

    if detailed
      base_attributes.merge({
        account_id: website.account_id,
        created_by_id: website.created_by_id,
        audit_reports_count: website.audit_reports.count,
        latest_audit_report: website.latest_audit_report ? audit_report_summary(website.latest_audit_report) : nil,
        display_url: website.display_url,
        should_monitor: website.should_monitor?,
        monitoring_overdue: website.monitoring_overdue?
      })
    else
      base_attributes
    end
  end

  def audit_report_summary(audit_report)
    {
      id: audit_report.id,
      overall_score: audit_report.overall_score,
      status: audit_report.status,
      created_at: audit_report.created_at,
      performance_grade: audit_report.performance_grade
    }
  end
end