class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # SEO optimization for production
  include SeoOptimized

  # Rate limiting for security
  include RateLimitable

  # Multi-tenant authentication and authorization
  before_action :authenticate_user!
  before_action :set_current_account
  before_action :ensure_account_active

  # Security and performance headers
  before_action :set_security_headers

  # General rate limiting for all requests (skipped for certain actions)
  before_action :rate_limit_general!, unless: :skip_rate_limiting?
  
  # Configure Devise parameters
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Global exception handling
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from Pundit::NotAuthorizedError, with: :render_forbidden if defined?(Pundit)
  
  private

  def skip_rate_limiting?
    # Skip rate limiting for health checks and static assets
    controller_name == 'health' ||
    controller_name == 'rails/health' ||
    request.path.start_with?('/assets/', '/packs/')
  end
  
  # Configure additional parameters for Devise
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
  end
  
  # Multi-tenant account management
  def set_current_account
    return unless user_signed_in?
    
    Current.user = current_user
    Current.account = current_user.account
  end
  
  def current_account
    Current.account
  end
  helper_method :current_account
  
  def ensure_account_active
    return unless user_signed_in? && current_account
    
    unless current_account.active?
      redirect_to account_suspended_path and return if current_account.suspended?
      redirect_to account_cancelled_path and return if current_account.cancelled?
      redirect_to billing_path, alert: 'Please update your billing information to continue.' and return if current_account.trial_expired?
    end
  end
  
  # Security headers for production
  def set_security_headers
    # Core security headers
    response.headers['X-Frame-Options'] = 'DENY'
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['X-XSS-Protection'] = '1; mode=block'
    response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'

    # Enhanced Permissions Policy to restrict dangerous features
    response.headers['Permissions-Policy'] = [
      'geolocation=()',
      'microphone=()',
      'camera=()',
      'payment=()',
      'usb=()',
      'magnetometer=()',
      'accelerometer=()',
      'gyroscope=()',
      'fullscreen=(self)',
      'picture-in-picture=()'
    ].join(', ')

    # Cache control for sensitive pages
    if request.path.include?('dashboard') || request.path.include?('account') || request.path.include?('billing')
      response.headers['Cache-Control'] = 'no-store, no-cache, must-revalidate, private'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = '0'
    end

    # Cross-Origin headers for enhanced isolation
    response.headers['Cross-Origin-Embedder-Policy'] = 'require-corp'
    response.headers['Cross-Origin-Opener-Policy'] = 'same-origin'
    response.headers['Cross-Origin-Resource-Policy'] = 'same-origin'

    # Always set CSP for all environments to enhance security
    response.headers['Content-Security-Policy'] = secure_csp_header

    # Production-specific security headers
    if Rails.env.production?
      response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains; preload'

      # Expect-CT header for Certificate Transparency
      response.headers['Expect-CT'] = 'max-age=86400, enforce'

      # Additional protection against MIME sniffing
      response.headers['X-Download-Options'] = 'noopen'
      response.headers['X-Permitted-Cross-Domain-Policies'] = 'none'
    end

    # Development-specific headers
    if Rails.env.development?
      # Allow HSTS but with shorter duration for development
      response.headers['Strict-Transport-Security'] = 'max-age=3600; includeSubDomains'
    end
  end
  
  def secure_csp_header
    # Generate a unique nonce for this request
    @csp_nonce ||= SecureRandom.base64(32)

    [
      "default-src 'self'",
      "script-src 'self' 'nonce-#{@csp_nonce}' https://cdn.tailwindcss.com https://www.googletagmanager.com",
      "style-src 'self' 'nonce-#{@csp_nonce}' https://cdn.tailwindcss.com 'unsafe-hashes'",
      "img-src 'self' data: https:",
      "font-src 'self' data:",
      "connect-src 'self' wss: https://www.google-analytics.com",
      "frame-ancestors 'none'",
      "object-src 'none'",
      "base-uri 'self'"
    ].join('; ')
  end

  # Helper method to get the CSP nonce for use in templates
  def csp_nonce
    @csp_nonce ||= SecureRandom.base64(32)
  end
  helper_method :csp_nonce
  
  # Exception handling
  def render_not_found(exception = nil)
    render json: { error: 'Resource not found' }, status: :not_found if request.format.json?
    render template: 'errors/404', status: :not_found, layout: 'error'
  end
  
  def render_bad_request(exception = nil)
    render json: { error: 'Bad request', message: exception&.message }, status: :bad_request if request.format.json?
    render template: 'errors/400', status: :bad_request, layout: 'error'
  end
  
  def render_forbidden(exception = nil)
    render json: { error: 'Access denied' }, status: :forbidden if request.format.json?
    render template: 'errors/403', status: :forbidden, layout: 'error'
  end
  
  # Helper methods for controllers
  def scoped_to_account(relation)
    return relation.none unless current_account
    
    # Check if the model has a direct account association
    if relation.column_names.include?('account_id')
      relation.where(account_id: current_account.id)
    # Handle models that belong to account through website
    elsif relation.reflect_on_association(:website)
      relation.joins(:website).where(websites: { account_id: current_account.id })
    # Handle models that have account association
    elsif relation.reflect_on_association(:account)
      relation.where(account: current_account)
    else
      relation.none
    end
  end
  
  def build_for_account(relation, attributes = {})
    return nil unless current_account
    relation.new(attributes.merge(account: current_account))
  end
  
  def authorize_account_owner!
    unless current_user&.owner?
      redirect_to root_path, alert: 'Access denied. Owner privileges required.'
    end
  end
  
  def authorize_account_admin!
    unless current_user&.can_manage?
      redirect_to root_path, alert: 'Access denied. Admin privileges required.'
    end
  end
  
  # Usage limit enforcement
  def check_usage_limit(feature, increment: 1)
    return true unless current_account
    
    unless current_account.within_usage_limits?(feature, increment)
      respond_to do |format|
        format.html { redirect_to billing_path, alert: "You've reached your #{feature.humanize.downcase} limit. Please upgrade your plan." }
        format.json { render json: { error: "Usage limit exceeded for #{feature}" }, status: :payment_required }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', partial: 'shared/usage_limit_error', locals: { feature: feature }) }
      end
      return false
    end
    true
  end
end