module Api
  module V1
    class BaseController < ActionController::API
      include RateLimitable

      # Rate limit all API requests
      before_action :rate_limit_api!

      # Authentication for API endpoints
      before_action :authenticate_api_user!

      private

      def authenticate_api_user!
        # For now, we'll use basic token authentication
        # In production, you might want to use JWT or OAuth
        token = request.headers['Authorization']&.remove('Bearer ')

        unless token.present?
          render json: { error: 'Missing authorization token' }, status: :unauthorized
          return
        end

        # Simple token validation (replace with your actual authentication logic)
        @current_user = User.joins(:account).find_by(
          'accounts.api_token = ? AND accounts.status = ?',
          token,
          'active'
        )

        unless @current_user
          render json: { error: 'Invalid or expired token' }, status: :unauthorized
          return
        end

        @current_account = @current_user.account
      end

      def current_user
        @current_user
      end

      def current_account
        @current_account
      end

      def handle_rate_limit_exceeded(action_type, config)
        # Override to provide JSON-only responses for API
        Rails.logger.warn(
          "API Rate limit exceeded: #{action_type} for #{client_identifier} " \
          "(limit: #{config[:limit]} per #{config[:period]} seconds)"
        )

        response.headers['X-RateLimit-Limit'] = config[:limit].to_s
        response.headers['X-RateLimit-Remaining'] = '0'
        response.headers['X-RateLimit-Reset'] = (Time.current + config[:period]).to_i.to_s
        response.headers['Retry-After'] = config[:period].to_s

        render json: {
          error: 'Rate limit exceeded',
          message: "Too many API requests. Limit: #{config[:limit]} per #{config[:period] / 60} minutes.",
          retry_after: config[:period]
        }, status: :too_many_requests
      end
    end
  end
end