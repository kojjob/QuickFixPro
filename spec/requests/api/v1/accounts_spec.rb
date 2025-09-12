require 'rails_helper'

RSpec.describe 'API::V1::Accounts', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, :admin, account: account) }
  let(:member_user) { create(:user, :member, account: account) }
  let(:viewer_user) { create(:user, :viewer, account: account) }
  let(:headers) { auth_headers_for(user) }

  describe 'GET /api/v1/accounts/:id' do
    context 'when authenticated as admin or owner' do
      before { get "/api/v1/accounts/#{account.id}", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns account details' do
        account_data = json_response['account']
        expect(account_data['id']).to eq(account.id)
        expect(account_data['name']).to eq(account.name)
        expect(account_data['subdomain']).to eq(account.subdomain)
        expect(account_data['status']).to eq(account.status)
        expect(account_data['display_name']).to eq(account.display_name)
      end

      it 'includes account statistics' do
        create_list(:website, 3, account: account)
        create_list(:user, 2, account: account)
        
        get "/api/v1/accounts/#{account.id}", headers: headers
        
        account_data = json_response['account']
        expect(account_data['statistics']).to include(
          'websites_count' => 3,
          'users_count' => 3, # 2 created + 1 admin user
          'total_audit_reports' => 0 # No audit reports created yet
        )
      end

      it 'includes subscription information' do
        subscription = create(:subscription, account: account)
        
        get "/api/v1/accounts/#{account.id}", headers: headers
        
        account_data = json_response['account']
        expect(account_data['subscription']).to be_a(Hash)
        expect(account_data['subscription']['id']).to eq(subscription.id)
        expect(account_data['subscription']).to include('plan', 'status', 'current_period_end')
      end

      it 'excludes sensitive information for non-owners' do
        member_headers = auth_headers_for(member_user)
        get "/api/v1/accounts/#{account.id}", headers: member_headers
        
        account_data = json_response['account']
        expect(account_data).not_to have_key('billing_details')
        expect(account_data).not_to have_key('payment_methods')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns basic account information only' do
        viewer_headers = auth_headers_for(viewer_user)
        get "/api/v1/accounts/#{account.id}", headers: viewer_headers
        
        expect_success_response
        account_data = json_response['account']
        expect(account_data).to include('id', 'name', 'display_name')
        expect(account_data).not_to have_key('statistics')
        expect(account_data).not_to have_key('subscription')
      end
    end

    context 'when trying to access different account' do
      let(:other_account) { create(:account) }
      
      it 'returns not found error' do
        get "/api/v1/accounts/#{other_account.id}", headers: headers
        expect_error_response(:not_found, 'Account not found')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        get "/api/v1/accounts/#{account.id}"
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end

    context 'when account is suspended' do
      let(:suspended_account) { create(:account, :suspended) }
      let(:suspended_user) { create(:user, account: suspended_account) }
      let(:suspended_headers) { auth_headers_for(suspended_user) }

      it 'returns account suspended error' do
        get "/api/v1/accounts/#{suspended_account.id}", headers: suspended_headers
        expect_error_response(:forbidden, 'Account suspended')
      end
    end
  end

  describe 'GET /api/v1/accounts/:id/usage_stats' do
    let!(:websites) { create_list(:website, 5, account: account) }
    let!(:audit_reports) do
      websites.flat_map do |website|
        create_list(:audit_report, 2, website: website)
      end
    end

    context 'when authenticated as admin or owner' do
      before { get "/api/v1/accounts/#{account.id}/usage_stats", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns current usage statistics' do
        usage_data = json_response['usage']
        expect(usage_data['current_period']).to include(
          'websites_count' => 5,
          'audit_reports_count' => 10,
          'api_calls_count' => 0 # Assuming no API calls tracked yet
        )
      end

      it 'includes usage limits from subscription' do
        subscription = create(:subscription, account: account, plan: 'professional')
        account.update!(current_subscription: subscription)
        
        get "/api/v1/accounts/#{account.id}/usage_stats", headers: headers
        
        usage_data = json_response['usage']
        expect(usage_data['limits']).to be_a(Hash)
        expect(usage_data['limits']).to include('websites', 'audit_reports', 'api_calls')
      end

      it 'calculates usage percentages' do
        usage_data = json_response['usage']
        expect(usage_data['usage_percentages']).to be_a(Hash)
        expect(usage_data['usage_percentages']).to include('websites', 'audit_reports', 'api_calls')
      end

      it 'includes historical usage trends' do
        usage_data = json_response['usage']
        expect(usage_data['trends']).to be_a(Hash)
        expect(usage_data['trends']).to include('daily', 'weekly', 'monthly')
      end

      it 'shows approaching limits warnings' do
        # Mock high usage scenario
        allow_any_instance_of(Account).to receive(:within_usage_limits?).and_return(false)
        
        get "/api/v1/accounts/#{account.id}/usage_stats", headers: headers
        
        usage_data = json_response['usage']
        expect(usage_data['warnings']).to be_an(Array)
        expect(usage_data['warnings']).not_to be_empty
      end
    end

    context 'when authenticated as member' do
      it 'returns limited usage information' do
        member_headers = auth_headers_for(member_user)
        get "/api/v1/accounts/#{account.id}/usage_stats", headers: member_headers
        
        expect_success_response
        usage_data = json_response['usage']
        expect(usage_data).to include('current_period')
        expect(usage_data).not_to have_key('billing_related_usage')
        expect(usage_data).not_to have_key('cost_analysis')
      end
    end

    context 'when authenticated as viewer' do
      it 'returns forbidden error' do
        viewer_headers = auth_headers_for(viewer_user)
        get "/api/v1/accounts/#{account.id}/usage_stats", headers: viewer_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end

    context 'with date range parameters' do
      it 'filters usage stats by date range' do
        from_date = 1.month.ago.to_date
        to_date = Date.current
        
        get "/api/v1/accounts/#{account.id}/usage_stats?from_date=#{from_date}&to_date=#{to_date}", 
            headers: headers
        
        expect_success_response
        usage_data = json_response['usage']
        expect(usage_data['period']).to include(
          'from' => from_date.to_s,
          'to' => to_date.to_s
        )
      end
    end

    context 'with granularity parameter' do
      it 'returns daily granularity usage data' do
        get "/api/v1/accounts/#{account.id}/usage_stats?granularity=daily", headers: headers
        
        expect_success_response
        usage_data = json_response['usage']
        expect(usage_data['breakdown']).to be_an(Array)
        expect(usage_data['breakdown'].first).to include('date', 'websites', 'audits', 'api_calls')
      end

      it 'returns monthly granularity usage data' do
        get "/api/v1/accounts/#{account.id}/usage_stats?granularity=monthly", headers: headers
        
        expect_success_response
        usage_data = json_response['usage']
        expect(usage_data['breakdown']).to be_an(Array)
        expect(usage_data['breakdown'].first).to include('month', 'websites', 'audits', 'api_calls')
      end
    end
  end

  describe 'PUT /api/v1/accounts/:id' do
    let(:update_attributes) do
      {
        account: {
          name: 'Updated Account Name'
        }
      }
    end

    context 'when authenticated as owner' do
      let(:owner_user) { create(:user, :owner, account: account) }
      let(:owner_headers) { auth_headers_for(owner_user) }

      context 'with valid parameters' do
        before do
          put "/api/v1/accounts/#{account.id}", 
              params: update_attributes.to_json, 
              headers: owner_headers
        end

        it 'returns successful response' do
          expect_success_response
        end

        it 'updates the account' do
          account.reload
          expect(account.name).to eq('Updated Account Name')
        end

        it 'returns updated account data' do
          account_data = json_response['account']
          expect(account_data['name']).to eq('Updated Account Name')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_attributes) do
          {
            account: {
              name: '',
              subdomain: 'invalid..subdomain'
            }
          }
        end

        it 'returns validation errors' do
          put "/api/v1/accounts/#{account.id}", 
              params: invalid_attributes.to_json, 
              headers: owner_headers
          
          expect_error_response(:unprocessable_entity, 'Validation failed')
          error_data = json_response
          expect(error_data['errors']).to include('name', 'subdomain')
        end
      end
    end

    context 'when authenticated as admin (non-owner)' do
      it 'returns forbidden error for sensitive updates' do
        sensitive_update = {
          account: {
            subdomain: 'new-subdomain',
            status: 'suspended'
          }
        }
        
        put "/api/v1/accounts/#{account.id}", 
            params: sensitive_update.to_json, 
            headers: headers
        expect_error_response(:forbidden, 'Owner privileges required')
      end

      it 'allows non-sensitive updates' do
        basic_update = {
          account: {
            name: 'New Name'
          }
        }
        
        put "/api/v1/accounts/#{account.id}", 
            params: basic_update.to_json, 
            headers: headers
        expect_success_response
      end
    end

    context 'when authenticated as member or viewer' do
      it 'returns forbidden error' do
        member_headers = auth_headers_for(member_user)
        put "/api/v1/accounts/#{account.id}", 
            params: update_attributes.to_json, 
            headers: member_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end

    context 'when trying to update different account' do
      let(:other_account) { create(:account) }
      
      it 'returns not found error' do
        put "/api/v1/accounts/#{other_account.id}", 
            params: update_attributes.to_json, 
            headers: headers
        expect_error_response(:not_found, 'Account not found')
      end
    end
  end

  describe 'POST /api/v1/accounts/:id/cancel_subscription' do
    let!(:subscription) { create(:subscription, account: account, status: :active) }

    context 'when authenticated as owner' do
      let(:owner_user) { create(:user, :owner, account: account) }
      let(:owner_headers) { auth_headers_for(owner_user) }

      it 'cancels the subscription' do
        post "/api/v1/accounts/#{account.id}/cancel_subscription", headers: owner_headers
        
        expect_success_response
        subscription.reload
        expect(subscription.status).to eq('cancelled')
      end

      it 'returns updated account information' do
        post "/api/v1/accounts/#{account.id}/cancel_subscription", headers: owner_headers
        
        account_data = json_response['account']
        expect(account_data['subscription']['status']).to eq('cancelled')
      end
    end

    context 'when authenticated as non-owner' do
      it 'returns forbidden error' do
        post "/api/v1/accounts/#{account.id}/cancel_subscription", headers: headers
        expect_error_response(:forbidden, 'Owner privileges required')
      end
    end

    context 'when no active subscription exists' do
      before { subscription.update!(status: :cancelled) }

      let(:owner_user) { create(:user, :owner, account: account) }
      let(:owner_headers) { auth_headers_for(owner_user) }

      it 'returns unprocessable entity error' do
        post "/api/v1/accounts/#{account.id}/cancel_subscription", headers: owner_headers
        expect_error_response(:unprocessable_entity, 'No active subscription to cancel')
      end
    end
  end
end