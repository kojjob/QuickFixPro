class Users::PasswordsController < Devise::PasswordsController
  include RateLimitable

  # Rate limit password reset requests to prevent abuse
  before_action :rate_limit_password_reset!, only: [:create]
  before_action :rate_limit_general!, only: [:new, :edit, :update]

  # GET /resource/password/new
  # def new
  #   super
  # end

  # POST /resource/password
  def create
    # Log password reset attempts for security monitoring
    Rails.logger.info "Password reset requested for email: #{params.dig(:user, :email)} from IP: #{request.remote_ip}"

    super do |resource|
      if successfully_sent?(resource)
        Rails.logger.info "Password reset email sent to: #{resource.email}"
      else
        Rails.logger.warn "Failed password reset attempt for email: #{params.dig(:user, :email)}"
      end
    end
  end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  def update
    # Log password update attempts
    Rails.logger.info "Password update attempt from IP: #{request.remote_ip}"

    super do |resource|
      if resource.errors.empty?
        Rails.logger.info "Password successfully updated for user: #{resource.email}"
      else
        Rails.logger.warn "Failed password update attempt"
      end
    end
  end

  protected

  # The path used after sending reset password instructions
  def after_sending_reset_password_instructions_path_for(resource_name)
    new_session_path(resource_name) if is_navigational_format?
  end

  # The path used after changing your password
  def after_resetting_password_path_for(resource)
    dashboard_path
  end
end