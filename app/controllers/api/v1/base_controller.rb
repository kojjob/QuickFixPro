class Api::V1::BaseController < Api::BaseController
  # V1 specific configurations and helpers
  
  private

  # V1 specific response format
  def render_success(data = {}, status: :ok)
    render json: data, status: status
  end

  def render_created(data = {})
    render json: data, status: :created
  end

  def render_no_content
    head :no_content
  end
end