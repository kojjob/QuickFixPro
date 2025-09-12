module JwtAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_jwt_user!
    before_action :set_current_account_from_jwt
    
    rescue_from JWT::DecodeError, with: :render_jwt_error
    rescue_from JWT::ExpiredSignature, with: :render_jwt_expired
  end

  private

  def authenticate_jwt_user!
    token = extract_token_from_header
    
    if token.blank?
      render_authentication_required
      return
    end

    decoded_token = decode_jwt_token(token)
    
    if decoded_token.nil?
      render_invalid_token
      return
    end

    @current_user = User.find_by(id: decoded_token['user_id'])
    
    unless @current_user
      render_invalid_token
      return
    end

    # Set Current context for request
    Current.user = @current_user
  rescue JWT::DecodeError => e
    render_jwt_error(e)
  rescue JWT::ExpiredSignature => e
    render_jwt_expired(e)
  end

  def set_current_account_from_jwt
    return unless @current_user
    
    # Set current account from user's account
    Current.account = @current_user.account
    @current_account = @current_user.account

    # Ensure account is active
    unless @current_account&.active? || @current_account&.trial?
      render_account_inactive
    end
  end

  def extract_token_from_header
    auth_header = request.headers['Authorization']
    return nil unless auth_header&.start_with?('Bearer ')
    
    auth_header.split(' ').last
  end

  def decode_jwt_token(token)
    JWT.decode(
      token,
      Rails.application.credentials.secret_key_base,
      true,
      algorithm: 'HS256'
    ).first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    nil
  end

  def current_user
    @current_user
  end

  def current_account
    @current_account
  end

  def render_authentication_required
    render json: { 
      error: 'Authentication required',
      message: 'Please provide a valid authorization token'
    }, status: :unauthorized
  end

  def render_invalid_token
    render json: { 
      error: 'Invalid token',
      message: 'The provided authentication token is invalid'
    }, status: :unauthorized
  end

  def render_jwt_error(exception)
    render json: { 
      error: 'Invalid token',
      message: 'Token format is invalid'
    }, status: :unauthorized
  end

  def render_jwt_expired(exception)
    render json: { 
      error: 'Token expired',
      message: 'The authentication token has expired'
    }, status: :unauthorized
  end

  def render_account_inactive
    render json: { 
      error: 'Account inactive',
      message: 'Account is suspended or cancelled'
    }, status: :forbidden
  end
end