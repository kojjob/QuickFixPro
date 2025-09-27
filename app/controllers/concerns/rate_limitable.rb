module RateLimitable
  extend ActiveSupport::Concern

  # Rate limiting configuration
  RATE_LIMITS = {
    # Authentication endpoints - protect against brute force
    authentication: { limit: 5, period: 15.minutes },
    # API endpoints - prevent API abuse
    api: { limit: 1000, period: 1.hour },
    # Form submissions - prevent spam
    form_submission: { limit: 10, period: 1.minute },
    # Password reset - prevent abuse
    password_reset: { limit: 3, period: 1.hour },
    # General requests - prevent DoS
    general: { limit: 300, period: 5.minutes }
  }.freeze

  private

  def check_rate_limit(action_type, identifier: nil)
    config = RATE_LIMITS[action_type]
    return true unless config

    # Create unique key for this action and client
    key = rate_limit_key(action_type, identifier)

    # Get current count
    current_count = Rails.cache.read(key) || 0

    # Check if limit exceeded
    if current_count >= config[:limit]
      handle_rate_limit_exceeded(action_type, config)
      return false
    end

    # Increment counter with expiry
    Rails.cache.write(key, current_count + 1, expires_in: config[:period])

    # Set rate limit headers
    set_rate_limit_headers(config, current_count + 1)

    true
  end

  def rate_limit_key(action_type, identifier = nil)
    client_id = identifier || client_identifier
    "rate_limit:#{action_type}:#{client_id}"
  end

  def client_identifier
    # Use IP address as primary identifier
    # In production, consider using user ID if authenticated
    ip_address = request.remote_ip

    # For authenticated users, use account-based limiting
    if user_signed_in? && current_user&.account
      "account:#{current_user.account.id}:#{ip_address}"
    else
      "ip:#{ip_address}"
    end
  end

  def handle_rate_limit_exceeded(action_type, config)
    # Log the rate limit violation for security monitoring
    Rails.logger.warn(
      "Rate limit exceeded: #{action_type} for #{client_identifier} " \
      "(limit: #{config[:limit]} per #{config[:period]} seconds)"
    )

    # Set appropriate headers
    response.headers['X-RateLimit-Limit'] = config[:limit].to_s
    response.headers['X-RateLimit-Remaining'] = '0'
    response.headers['X-RateLimit-Reset'] = (Time.current + config[:period]).to_i.to_s
    response.headers['Retry-After'] = config[:period].to_s

    # Respond based on request format
    respond_to do |format|
      format.html do
        flash[:error] = "Too many requests. Please try again later."
        redirect_back(fallback_location: root_path)
      end

      format.json do
        render json: {
          error: 'Rate limit exceeded',
          message: "Too many requests. Limit: #{config[:limit]} per #{config[:period] / 60} minutes.",
          retry_after: config[:period]
        }, status: :too_many_requests
      end

      format.any do
        head :too_many_requests
      end
    end
  end

  def set_rate_limit_headers(config, current_count)
    response.headers['X-RateLimit-Limit'] = config[:limit].to_s
    response.headers['X-RateLimit-Remaining'] = (config[:limit] - current_count).to_s
    response.headers['X-RateLimit-Reset'] = (Time.current + config[:period]).to_i.to_s
  end

  # Convenience methods for common rate limiting scenarios
  def rate_limit_authentication!
    check_rate_limit(:authentication) || return
  end

  def rate_limit_api!
    check_rate_limit(:api) || return
  end

  def rate_limit_form_submission!
    check_rate_limit(:form_submission) || return
  end

  def rate_limit_password_reset!
    check_rate_limit(:password_reset) || return
  end

  def rate_limit_general!
    check_rate_limit(:general) || return
  end
end