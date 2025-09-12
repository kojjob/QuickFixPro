require 'rails_helper'

RSpec.describe 'API::V1::AuditReports', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, :admin, account: account) }
  let(:website) { create(:website, account: account) }
  let(:other_account) { create(:account) }
  let(:other_website) { create(:website, account: other_account) }
  let(:headers) { auth_headers_for(user) }

  describe 'GET /api/v1/websites/:website_id/audit_reports' do
    let!(:audit_report1) { create(:audit_report, website: website, overall_score: 85) }
    let!(:audit_report2) { create(:audit_report, website: website, overall_score: 92, :high_score) }
    let!(:other_audit) { create(:audit_report, website: other_website) }

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}/audit_reports", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns audit reports for the specific website' do
        json_data = json_response
        expect(json_data['audit_reports']).to be_an(Array)
        expect(json_data['audit_reports'].length).to eq(2)
        
        report_ids = json_data['audit_reports'].map { |r| r['id'] }
        expect(report_ids).to include(audit_report1.id, audit_report2.id)
        expect(report_ids).not_to include(other_audit.id)
      end

      it 'includes proper audit report attributes' do
        report_data = json_response['audit_reports'].first
        expect(report_data).to include(
          'id', 'overall_score', 'audit_type', 'status', 'started_at', 
          'completed_at', 'duration', 'performance_grade', 'created_at'
        )
      end

      it 'orders reports by creation date descending' do
        json_data = json_response
        reports = json_data['audit_reports']
        expect(reports.first['id']).to eq(audit_report2.id) # Most recent first
      end

      it 'includes pagination metadata' do
        json_data = json_response
        expect(json_data).to include('pagination')
        expect(json_data['pagination']).to include(
          'current_page', 'total_pages', 'total_count', 'per_page'
        )
      end
    end

    context 'when trying to access reports for website from different account' do
      it 'returns not found error' do
        get "/api/v1/websites/#{other_website.id}/audit_reports", headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        get "/api/v1/websites/#{website.id}/audit_reports"
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end

    context 'with filtering parameters' do
      let!(:completed_report) { create(:audit_report, website: website, status: :completed) }
      let!(:failed_report) { create(:audit_report, website: website, :failed) }

      it 'filters by status' do
        get "/api/v1/websites/#{website.id}/audit_reports?status=completed", headers: headers
        
        expect_success_response
        json_data = json_response
        statuses = json_data['audit_reports'].map { |r| r['status'] }
        expect(statuses).to all(eq('completed'))
      end

      it 'filters by score range' do
        get "/api/v1/websites/#{website.id}/audit_reports?min_score=90", headers: headers
        
        expect_success_response
        json_data = json_response
        scores = json_data['audit_reports'].map { |r| r['overall_score'] }
        expect(scores).to all(be >= 90)
      end
    end
  end

  describe 'GET /api/v1/websites/:website_id/audit_reports/:id' do
    let(:audit_report) { create(:audit_report, website: website) }
    let!(:performance_metrics) do
      [
        create(:performance_metric, :lcp, audit_report: audit_report),
        create(:performance_metric, :fid, audit_report: audit_report),
        create(:performance_metric, :cls, audit_report: audit_report)
      ]
    end

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}/audit_reports/#{audit_report.id}", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns detailed audit report data' do
        report_data = json_response['audit_report']
        expect(report_data['id']).to eq(audit_report.id)
        expect(report_data['website_id']).to eq(website.id)
        expect(report_data['overall_score']).to eq(audit_report.overall_score)
        expect(report_data['raw_results']).to eq(audit_report.raw_results)
        expect(report_data['summary_data']).to eq(audit_report.summary_data)
      end

      it 'includes performance metrics' do
        report_data = json_response['audit_report']
        expect(report_data['performance_metrics']).to be_an(Array)
        expect(report_data['performance_metrics'].length).to eq(3)
        
        metric_types = report_data['performance_metrics'].map { |m| m['metric_type'] }
        expect(metric_types).to include('lcp', 'fid', 'cls')
      end

      it 'includes core web vitals separately' do
        report_data = json_response['audit_report']
        expect(report_data['core_web_vitals']).to be_an(Array)
        expect(report_data['core_web_vitals'].length).to eq(3)
      end

      it 'includes optimization recommendations count' do
        create_list(:optimization_recommendation, 2, audit_report: audit_report)
        get "/api/v1/websites/#{website.id}/audit_reports/#{audit_report.id}", headers: headers
        
        report_data = json_response['audit_report']
        expect(report_data['recommendations_count']).to eq(2)
      end
    end

    context 'when trying to access report from different account' do
      let(:other_report) { create(:audit_report, website: other_website) }

      it 'returns not found error' do
        get "/api/v1/websites/#{other_website.id}/audit_reports/#{other_report.id}", headers: headers
        expect_error_response(:not_found, 'Audit report not found')
      end
    end

    context 'when report does not exist' do
      it 'returns not found error' do
        get "/api/v1/websites/#{website.id}/audit_reports/999999", headers: headers
        expect_error_response(:not_found, 'Audit report not found')
      end
    end
  end

  describe 'POST /api/v1/websites/:website_id/audit_reports' do
    let(:valid_attributes) do
      {
        audit_report: {
          audit_type: 'api_triggered'
        }
      }
    end

    let(:invalid_attributes) do
      {
        audit_report: {
          audit_type: 'invalid_type'
        }
      }
    end

    context 'when authenticated and authorized' do
      context 'with valid parameters' do
        it 'creates a new audit report' do
          expect {
            post "/api/v1/websites/#{website.id}/audit_reports", 
                 params: valid_attributes.to_json, headers: headers
          }.to change(AuditReport, :count).by(1)
          
          expect_success_response(:created)
        end

        it 'returns created audit report data' do
          post "/api/v1/websites/#{website.id}/audit_reports", 
               params: valid_attributes.to_json, headers: headers
          
          report_data = json_response['audit_report']
          expect(report_data['website_id']).to eq(website.id)
          expect(report_data['audit_type']).to eq('api_triggered')
          expect(report_data['status']).to eq('pending')
          expect(report_data['triggered_by_id']).to eq(user.id)
        end

        it 'enqueues audit processing job' do
          expect {
            post "/api/v1/websites/#{website.id}/audit_reports", 
                 params: valid_attributes.to_json, headers: headers
          }.to have_enqueued_job # Assuming you have audit processing job
        end

        it 'defaults to manual audit type if not specified' do
          post "/api/v1/websites/#{website.id}/audit_reports", 
               params: {}, headers: headers
          
          report_data = json_response['audit_report']
          expect(report_data['audit_type']).to eq('manual')
        end
      end

      context 'with invalid parameters' do
        it 'returns validation errors' do
          post "/api/v1/websites/#{website.id}/audit_reports", 
               params: invalid_attributes.to_json, headers: headers
          
          expect_error_response(:unprocessable_entity, 'Validation failed')
        end
      end

      context 'when website has pending audit' do
        let!(:pending_audit) { create(:audit_report, :pending, website: website) }

        it 'returns conflict error' do
          post "/api/v1/websites/#{website.id}/audit_reports", 
               params: valid_attributes.to_json, headers: headers
          
          expect_error_response(:conflict, 'Audit already in progress')
        end
      end

      context 'when account usage limit is exceeded' do
        before do
          allow_any_instance_of(Account).to receive(:within_usage_limits?).and_return(false)
        end

        it 'returns payment required error' do
          post "/api/v1/websites/#{website.id}/audit_reports", 
               params: valid_attributes.to_json, headers: headers
          expect_error_response(:payment_required, 'Usage limit exceeded')
        end
      end
    end

    context 'when user has insufficient permissions' do
      let(:viewer_user) { create(:user, :viewer, account: account) }
      let(:viewer_headers) { auth_headers_for(viewer_user) }

      it 'returns forbidden error' do
        post "/api/v1/websites/#{website.id}/audit_reports", 
             params: valid_attributes.to_json, headers: viewer_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end

    context 'when trying to create audit for website from different account' do
      it 'returns not found error' do
        post "/api/v1/websites/#{other_website.id}/audit_reports", 
             params: valid_attributes.to_json, headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end
  end

  describe 'DELETE /api/v1/websites/:website_id/audit_reports/:id' do
    let!(:audit_report) { create(:audit_report, :pending, website: website) }

    context 'when authenticated and authorized as admin' do
      it 'cancels the pending audit report' do
        delete "/api/v1/websites/#{website.id}/audit_reports/#{audit_report.id}", headers: headers
        
        expect(response).to have_http_status(:no_content)
        audit_report.reload
        expect(audit_report.status).to eq('cancelled')
      end
    end

    context 'when trying to cancel completed audit' do
      let(:completed_audit) { create(:audit_report, :completed, website: website) }

      it 'returns unprocessable entity error' do
        delete "/api/v1/websites/#{website.id}/audit_reports/#{completed_audit.id}", headers: headers
        expect_error_response(:unprocessable_entity, 'Cannot cancel completed audit')
      end
    end

    context 'when user has insufficient permissions' do
      let(:member_user) { create(:user, :member, account: account) }
      let(:member_headers) { auth_headers_for(member_user) }

      it 'returns forbidden error' do
        delete "/api/v1/websites/#{website.id}/audit_reports/#{audit_report.id}", headers: member_headers
        expect_error_response(:forbidden, 'Insufficient permissions')
      end
    end
  end
end