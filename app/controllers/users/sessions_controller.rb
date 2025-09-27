class Users::SessionsController < Devise::SessionsController
  include RateLimitable

  # Rate limit login attempts to prevent brute force attacks
  before_action :rate_limit_authentication!, only: [:create]
  before_action :rate_limit_general!, only: [:new, :destroy]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  def create
    # Log authentication attempts for security monitoring
    Rails.logger.info "Authentication attempt for email: #{params.dig(:user, :email)} from IP: #{request.remote_ip}"

    super do |resource|
      if resource.persisted?
        Rails.logger.info "Successful authentication for user: #{resource.email} from IP: #{request.remote_ip}"

        # Optional: Reset failed login attempts counter on successful login
        clear_rate_limit_counter(:authentication)
      else
        Rails.logger.warn "Failed authentication attempt for email: #{params.dig(:user, :email)} from IP: #{request.remote_ip}"
      end
    end
  end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  private

  def clear_rate_limit_counter(action_type)
    key = rate_limit_key(action_type)
    Rails.cache.delete(key)
  end

  # The path used after signing in
  def after_sign_in_path_for(resource)
    if resource.account&.suspended?
      account_suspended_path
    elsif resource.account&.cancelled?
      account_cancelled_path
    elsif resource.account&.trial_expired?
      billing_path
    else
      dashboard_path
    end
  end

  # The path used after signing out
  def after_sign_out_path_for(resource_or_scope)
    root_path
  end
end