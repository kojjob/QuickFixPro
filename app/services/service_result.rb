class ServiceResult
  attr_reader :success, :data, :error

  def initialize(success:, data: {}, error: nil)
    @success = success
    @data = data
    @error = error
  end

  def success?
    @success
  end

  def failure?
    !@success
  end
end
