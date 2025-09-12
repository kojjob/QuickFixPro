require 'rails_helper'

RSpec.describe 'API::V1::Websites', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, :admin, account: account) }
  let(:other_account) { create(:account) }
  let(:other_user) { create(:user, account: other_account) }
  let(:headers) { auth_headers_for(user) }
  let(:invalid_headers) { auth_headers_for(other_user) }

  describe 'GET /api/v1/websites' do
    let!(:website1) { create(:website, account: account) }
    let!(:website2) { create(:website, :paused, account: account) }
    let!(:other_website) { create(:website, account: other_account) }

    context 'when authenticated and authorized' do
      before { get '/api/v1/websites', headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns only websites for current account' do
        json_data = json_response
        expect(json_data['websites']).to be_an(Array)
        expect(json_data['websites'].length).to eq(2)
        
        website_ids = json_data['websites'].map { |w| w['id'] }
        expect(website_ids).to include(website1.id, website2.id)
        expect(website_ids).not_to include(other_website.id)
      end

      it 'includes proper website attributes' do
        website_data = json_response['websites'].first
        expect(website_data).to include(
          'id', 'name', 'url', 'status', 'monitoring_frequency', 
          'current_score', 'performance_grade', 'last_monitored_at',
          'created_at', 'updated_at'
        )
      end

      it 'includes pagination metadata' do
        json_data = json_response
        expect(json_data).to include('pagination')
        expect(json_data['pagination']).to include(
          'current_page', 'total_pages', 'total_count', 'per_page'
        )
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        get '/api/v1/websites'
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end

    context 'when authenticated with invalid token' do
      it 'returns unauthorized error' do
        get '/api/v1/websites', headers: { 'Authorization' => 'Bearer invalid-token' }
        expect_error_response(:unauthorized, 'Invalid token')
      end
    end

    context 'with pagination parameters' do
      before do
        create_list(:website, 15, account: account)
      end

      it 'respects page parameter' do
        get '/api/v1/websites?page=2&per_page=5', headers: headers
        
        expect_success_response
        json_data = json_response
        expect(json_data['pagination']['current_page']).to eq(2)
        expect(json_data['websites'].length).to be <= 5
      end

      it 'respects per_page parameter' do
        get '/api/v1/websites?per_page=10', headers: headers
        
        expect_success_response
        json_data = json_response
        expect(json_data['websites'].length).to be <= 10
        expect(json_data['pagination']['per_page']).to eq(10)
      end
    end

    context 'with filtering parameters' do
      let!(:active_website) { create(:website, account: account, status: :active) }
      let!(:paused_website) { create(:website, account: account, status: :paused) }

      it 'filters by status' do
        get '/api/v1/websites?status=active', headers: headers
        
        expect_success_response
        json_data = json_response
        statuses = json_data['websites'].map { |w| w['status'] }
        expect(statuses).to all(eq('active'))
      end
    end
  end

  describe 'GET /api/v1/websites/:id' do
    let(:website) { create(:website, account: account) }
    let(:other_account_website) { create(:website, account: other_account) }

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns website details' do
        website_data = json_response['website']
        expect(website_data['id']).to eq(website.id)
        expect(website_data['name']).to eq(website.name)
        expect(website_data['url']).to eq(website.url)
        expect(website_data['account_id']).to eq(account.id)
      end

      it 'includes audit reports summary' do
        create_list(:audit_report, 3, website: website)
        get "/api/v1/websites/#{website.id}", headers: headers
        
        website_data = json_response['website']
        expect(website_data['audit_reports_count']).to eq(3)
        expect(website_data).to have_key('latest_audit_report')
      end
    end

    context 'when trying to access website from different account' do
      it 'returns not found error' do
        get "/api/v1/websites/#{other_account_website.id}", headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end

    context 'when website does not exist' do
      it 'returns not found error' do
        get '/api/v1/websites/999999', headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        get "/api/v1/websites/#{website.id}"
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end
  end

  describe 'POST /api/v1/websites' do
    let(:valid_attributes) do
      {
        website: {
          name: 'Test Website',
          url: 'https://test.example.com',
          monitoring_frequency: 'daily'
        }
      }
    end

    let(:invalid_attributes) do
      {
        website: {
          name: '',
          url: 'invalid-url',
          monitoring_frequency: 'invalid'
        }
      }
    end

    context 'when authenticated and authorized' do
      context 'with valid parameters' do
        it 'creates a new website' do
          expect {
            post '/api/v1/websites', params: valid_attributes.to_json, headers: headers
          }.to change(Website, :count).by(1)
          
          expect_success_response(:created)
        end

        it 'returns created website data' do
          post '/api/v1/websites', params: valid_attributes.to_json, headers: headers
          
          website_data = json_response['website']
          expect(website_data['name']).to eq('Test Website')
          expect(website_data['url']).to eq('https://test.example.com')
          expect(website_data['account_id']).to eq(account.id)
          expect(website_data['created_by_id']).to eq(user.id)
        end

        it 'sets website to active status by default' do
          post '/api/v1/websites', params: valid_attributes.to_json, headers: headers
          
          website_data = json_response['website']
          expect(website_data['status']).to eq('active')
        end
      end

      context 'with invalid parameters' do
        it 'does not create a website' do
          expect {
            post '/api/v1/websites', params: invalid_attributes.to_json, headers: headers
          }.not_to change(Website, :count)
        end

        it 'returns validation errors' do
          post '/api/v1/websites', params: invalid_attributes.to_json, headers: headers
          
          expect_error_response(:unprocessable_entity, 'Validation failed')
          error_data = json_response
          expect(error_data['errors']).to be_present
          expect(error_data['errors']['name']).to include("can't be blank")
          expect(error_data['errors']['url']).to include('is invalid')
        end
      end

      context 'when account usage limit is exceeded' do
        before do
          allow_any_instance_of(Account).to receive(:within_usage_limits?).and_return(false)
        end

        it 'returns payment required error' do
          post '/api/v1/websites', params: valid_attributes.to_json, headers: headers
          expect_error_response(:payment_required, 'Usage limit exceeded')
        end
      end
    end

    context 'when user has insufficient permissions' do
      let(:viewer_user) { create(:user, :viewer, account: account) }
      let(:viewer_headers) { auth_headers_for(viewer_user) }

      it 'returns forbidden error' do
        post '/api/v1/websites', params: valid_attributes.to_json, headers: viewer_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        post '/api/v1/websites', params: valid_attributes.to_json
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end
  end

  describe 'PUT /api/v1/websites/:id' do
    let(:website) { create(:website, account: account) }
    let(:update_attributes) do
      {
        website: {
          name: 'Updated Website',
          monitoring_frequency: 'weekly'
        }
      }
    end

    context 'when authenticated and authorized' do
      context 'with valid parameters' do
        before do
          put "/api/v1/websites/#{website.id}", 
              params: update_attributes.to_json, 
              headers: headers
        end

        it 'returns successful response' do
          expect_success_response
        end

        it 'updates the website' do
          website.reload
          expect(website.name).to eq('Updated Website')
          expect(website.monitoring_frequency).to eq('weekly')
        end

        it 'returns updated website data' do
          website_data = json_response['website']
          expect(website_data['name']).to eq('Updated Website')
          expect(website_data['monitoring_frequency']).to eq('weekly')
        end
      end

      context 'with invalid parameters' do
        let(:invalid_update) do
          {
            website: {
              name: '',
              url: 'invalid-url'
            }
          }
        end

        it 'returns validation errors' do
          put "/api/v1/websites/#{website.id}", 
              params: invalid_update.to_json, 
              headers: headers
          
          expect_error_response(:unprocessable_entity, 'Validation failed')
        end

        it 'does not update the website' do
          original_name = website.name
          put "/api/v1/websites/#{website.id}", 
              params: invalid_update.to_json, 
              headers: headers
          
          website.reload
          expect(website.name).to eq(original_name)
        end
      end
    end

    context 'when trying to update website from different account' do
      let(:other_website) { create(:website, account: other_account) }

      it 'returns not found error' do
        put "/api/v1/websites/#{other_website.id}", 
            params: update_attributes.to_json, 
            headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end

    context 'when user has insufficient permissions' do
      let(:viewer_user) { create(:user, :viewer, account: account) }
      let(:viewer_headers) { auth_headers_for(viewer_user) }

      it 'returns forbidden error' do
        put "/api/v1/websites/#{website.id}", 
            params: update_attributes.to_json, 
            headers: viewer_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end
  end

  describe 'DELETE /api/v1/websites/:id' do
    let!(:website) { create(:website, account: account) }

    context 'when authenticated and authorized' do
      it 'deletes the website' do
        expect {
          delete "/api/v1/websites/#{website.id}", headers: headers
        }.to change(Website, :count).by(-1)
      end

      it 'returns successful response' do
        delete "/api/v1/websites/#{website.id}", headers: headers
        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when user has insufficient permissions' do
      let(:member_user) { create(:user, :member, account: account) }
      let(:member_headers) { auth_headers_for(member_user) }

      it 'returns forbidden error' do
        delete "/api/v1/websites/#{website.id}", headers: member_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end

    context 'when trying to delete website from different account' do
      let(:other_website) { create(:website, account: other_account) }

      it 'returns not found error' do
        delete "/api/v1/websites/#{other_website.id}", headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end
  end
end