class Api::BaseController < ActionController::API
  include JwtAuthenticatable
  
  # Standard error handling for API
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :render_validation_errors
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  rescue_from StandardError, with: :render_internal_error
  
  private

  # Account scoping helpers
  def scoped_to_current_account(relation)
    return relation.none unless current_account
    
    if relation.column_names.include?('account_id')
      relation.where(account_id: current_account.id)
    elsif relation.reflect_on_association(:website)
      relation.joins(:website).where(websites: { account_id: current_account.id })
    elsif relation.reflect_on_association(:account)
      relation.where(account: current_account)
    else
      relation.none
    end
  end

  def build_for_current_account(relation, attributes = {})
    return nil unless current_account
    
    if relation.column_names.include?('account_id')
      relation.new(attributes.merge(account: current_account))
    else
      relation.new(attributes)
    end
  end

  # Authorization helpers
  def authorize_account_owner!
    unless current_user&.owner?
      render_insufficient_permissions('Owner privileges required')
    end
  end

  def authorize_account_admin!
    unless current_user&.can_manage_account?
      render_insufficient_permissions('Admin privileges required')
    end
  end

  def authorize_website_access!(website_id)
    website = scoped_to_current_account(Website).find(website_id)
    website
  rescue ActiveRecord::RecordNotFound
    render_not_found('Website not found')
    nil
  end

  def check_user_permissions!(required_permission)
    case required_permission
    when :create_websites, :trigger_audits
      unless current_user.can_create_websites?
        render_insufficient_permissions('Insufficient permissions')
        return false
      end
    when :view_billing
      unless current_user.can_view_billing?
        render_insufficient_permissions('Insufficient permissions')
        return false
      end
    end
    true
  end

  # Usage limits
  def check_usage_limit!(feature, increment: 1)
    return true unless current_account
    
    unless current_account.within_usage_limits?(feature, increment)
      render_usage_limit_exceeded(feature)
      return false
    end
    true
  end

  # Pagination helper
  def paginate_collection(collection, page: params[:page], per_page: params[:per_page])
    per_page = [per_page&.to_i || 20, 100].min # Max 100 per page
    page = [page&.to_i || 1, 1].max # Min page 1
    
    paginated = collection.page(page).per(per_page)
    
    {
      collection: paginated,
      pagination: {
        current_page: paginated.current_page,
        total_pages: paginated.total_pages,
        total_count: paginated.total_count,
        per_page: paginated.limit_value,
        has_next_page: paginated.next_page.present?,
        has_prev_page: paginated.prev_page.present?
      }
    }
  end

  # Error response helpers
  def render_not_found(message = 'Resource not found')
    render json: { 
      error: message
    }, status: :not_found
  end

  def render_validation_errors(exception)
    render json: {
      error: 'Validation failed',
      errors: exception.record.errors.as_json
    }, status: :unprocessable_entity
  end

  def render_parameter_missing(exception)
    render json: {
      error: 'Bad request',
      message: exception.message
    }, status: :bad_request
  end

  def render_insufficient_permissions(message = 'Insufficient permissions')
    render json: {
      error: message
    }, status: :forbidden
  end

  def render_usage_limit_exceeded(feature)
    render json: {
      error: 'Usage limit exceeded',
      message: "You've reached your #{feature.to_s.humanize.downcase} limit. Please upgrade your plan."
    }, status: :payment_required
  end

  def render_conflict(message)
    render json: {
      error: message
    }, status: :conflict
  end

  def render_internal_error(exception)
    if Rails.env.development?
      render json: {
        error: 'Internal server error',
        message: exception.message,
        backtrace: exception.backtrace[0..10]
      }, status: :internal_server_error
    else
      Rails.logger.error "API Internal Error: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n")
      
      render json: {
        error: 'Internal server error',
        message: 'An unexpected error occurred'
      }, status: :internal_server_error
    end
  end
end