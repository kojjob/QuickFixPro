module ApiHelpers
  # JWT token generation for API authentication
  def jwt_token_for(user)
    # This is a basic JWT token generation - adjust based on your actual JWT implementation
    payload = {
      user_id: user.id,
      account_id: user.account_id,
      exp: 1.hour.from_now.to_i
    }
    
    # Using a simple secret - replace with your actual JWT secret
    JWT.encode(payload, Rails.application.credentials.secret_key_base, 'HS256')
  end
  
  # Generate Authorization header for API requests
  def auth_headers_for(user)
    {
      'Authorization' => "Bearer #{jwt_token_for(user)}",
      'Content-Type' => 'application/json',
      'Accept' => 'application/json'
    }
  end
  
  # Helper to parse JSON response
  def json_response
    JSON.parse(response.body)
  end
  
  # Helper to expect JSON response structure
  def expect_json_response(expected_keys = [])
    expect(response.content_type).to include('application/json')
    parsed_response = json_response
    expected_keys.each do |key|
      expect(parsed_response).to have_key(key.to_s)
    end
    parsed_response
  end
  
  # Expect standard API error response
  def expect_error_response(status, error_type = nil)
    expect(response).to have_http_status(status)
    parsed = expect_json_response(['error'])
    expect(parsed['error']).to eq(error_type) if error_type
    parsed
  end
  
  # Expect successful API response with data
  def expect_success_response(status = :ok)
    expect(response).to have_http_status(status)
    expect_json_response
  end
  
  # Helper to create account-scoped resource for testing
  def create_resource_for_account(factory_name, account, attributes = {})
    create(factory_name, attributes.merge(account: account))
  end
  
  # Helper to create user in account
  def create_user_in_account(account, role = :member, attributes = {})
    create(:user, attributes.merge(account: account, role: role))
  end
end