require 'rails_helper'

RSpec.describe 'API::V1::Webhooks', type: :request do
  let(:account) { create(:account) }
  let(:website) { create(:website, account: account) }
  
  # Webhook authentication - typically using API keys or signatures
  let(:valid_webhook_headers) do
    {
      'Content-Type' => 'application/json',
      'X-Webhook-Secret' => Rails.application.credentials.webhook_secret || 'test_webhook_secret',
      'X-Webhook-Signature' => webhook_signature
    }
  end
  
  let(:invalid_webhook_headers) do
    {
      'Content-Type' => 'application/json',
      'X-Webhook-Secret' => 'invalid_secret'
    }
  end

  describe 'POST /api/v1/webhooks/audit_completed' do
    let(:valid_payload) do
      {
        website_id: website.id,
        audit_report_id: audit_report.id,
        overall_score: 85,
        status: 'completed',
        results: {
          performance: 85,
          seo: 90,
          accessibility: 80,
          best_practices: 88
        },
        metrics: [
          {
            metric_type: 'lcp',
            value: 2000,
            threshold_status: 'good'
          },
          {
            metric_type: 'fid',
            value: 50,
            threshold_status: 'good'
          },
          {
            metric_type: 'cls',
            value: 0.05,
            threshold_status: 'good'
          }
        ],
        completed_at: Time.current.iso8601
      }
    end

    let(:audit_report) { create(:audit_report, :running, website: website) }
    let(:webhook_signature) { generate_webhook_signature(valid_payload.to_json) }

    context 'with valid webhook authentication' do
      context 'with valid payload' do
        before do
          post '/api/v1/webhooks/audit_completed',
               params: valid_payload.to_json,
               headers: valid_webhook_headers
        end

        it 'returns successful response' do
          expect(response).to have_http_status(:ok)
          json_data = json_response
          expect(json_data['status']).to eq('success')
          expect(json_data['message']).to eq('Audit completed successfully')
        end

        it 'updates the audit report status' do
          audit_report.reload
          expect(audit_report.status).to eq('completed')
          expect(audit_report.overall_score).to eq(85)
          expect(audit_report.completed_at).to be_present
        end

        it 'creates performance metrics' do
          expect(audit_report.performance_metrics.count).to eq(3)
          
          lcp_metric = audit_report.performance_metrics.find_by(metric_type: 'lcp')
          expect(lcp_metric.value).to eq(2000)
          expect(lcp_metric.threshold_status).to eq('good')
        end

        it 'updates website current score' do
          website.reload
          expect(website.current_score).to eq(85)
          expect(website.last_monitored_at).to be_present
        end

        it 'stores raw results data' do
          audit_report.reload
          expect(audit_report.raw_results).to include(
            'performance' => 85,
            'seo' => 90,
            'accessibility' => 80,
            'best_practices' => 88
          )
        end

        it 'triggers real-time notifications' do
          # Assuming you have ActionCable or similar for real-time updates
          expect {
            post '/api/v1/webhooks/audit_completed',
                 params: valid_payload.to_json,
                 headers: valid_webhook_headers
          }.to have_broadcasted_to("account_#{account.id}_audit_reports")
        end
      end

      context 'with invalid payload' do
        let(:invalid_payload) do
          {
            website_id: website.id,
            # Missing required fields
            status: 'completed'
          }
        end
        let(:webhook_signature) { generate_webhook_signature(invalid_payload.to_json) }

        it 'returns validation error' do
          post '/api/v1/webhooks/audit_completed',
               params: invalid_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:bad_request)
          json_data = json_response
          expect(json_data['error']).to eq('Invalid payload')
          expect(json_data['errors']).to be_present
        end
      end

      context 'when audit report is not in running state' do
        let(:completed_audit) { create(:audit_report, :completed, website: website) }
        let(:invalid_state_payload) do
          valid_payload.merge(audit_report_id: completed_audit.id)
        end
        let(:webhook_signature) { generate_webhook_signature(invalid_state_payload.to_json) }

        it 'returns conflict error' do
          post '/api/v1/webhooks/audit_completed',
               params: invalid_state_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:conflict)
          json_data = json_response
          expect(json_data['error']).to eq('Audit report is not in running state')
        end
      end

      context 'when website does not exist' do
        let(:nonexistent_payload) do
          valid_payload.merge(website_id: 999999)
        end
        let(:webhook_signature) { generate_webhook_signature(nonexistent_payload.to_json) }

        it 'returns not found error' do
          post '/api/v1/webhooks/audit_completed',
               params: nonexistent_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:not_found)
          json_data = json_response
          expect(json_data['error']).to eq('Website not found')
        end
      end

      context 'with failed audit status' do
        let(:failed_payload) do
          {
            website_id: website.id,
            audit_report_id: audit_report.id,
            status: 'failed',
            error_message: 'Network timeout during audit',
            failed_at: Time.current.iso8601
          }
        end
        let(:webhook_signature) { generate_webhook_signature(failed_payload.to_json) }

        it 'marks audit as failed' do
          post '/api/v1/webhooks/audit_completed',
               params: failed_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:ok)
          audit_report.reload
          expect(audit_report.status).to eq('failed')
          expect(audit_report.error_message).to eq('Network timeout during audit')
          expect(audit_report.overall_score).to be_nil
        end
      end
    end

    context 'with invalid webhook authentication' do
      it 'returns unauthorized error for invalid secret' do
        post '/api/v1/webhooks/audit_completed',
             params: valid_payload.to_json,
             headers: invalid_webhook_headers
        
        expect(response).to have_http_status(:unauthorized)
        json_data = json_response
        expect(json_data['error']).to eq('Invalid webhook authentication')
      end

      it 'returns unauthorized error for invalid signature' do
        invalid_signature_headers = valid_webhook_headers.merge(
          'X-Webhook-Signature' => 'invalid_signature'
        )
        
        post '/api/v1/webhooks/audit_completed',
             params: valid_payload.to_json,
             headers: invalid_signature_headers
        
        expect(response).to have_http_status(:unauthorized)
        json_data = json_response
        expect(json_data['error']).to eq('Invalid webhook signature')
      end
    end

    context 'with missing webhook headers' do
      it 'returns unauthorized error' do
        post '/api/v1/webhooks/audit_completed',
             params: valid_payload.to_json,
             headers: { 'Content-Type' => 'application/json' }
        
        expect(response).to have_http_status(:unauthorized)
        json_data = json_response
        expect(json_data['error']).to eq('Missing webhook authentication')
      end
    end
  end

  describe 'POST /api/v1/webhooks/performance_alert' do
    let(:valid_alert_payload) do
      {
        website_id: website.id,
        alert_type: 'performance_degradation',
        severity: 'high',
        message: 'Core Web Vitals performance has degraded significantly',
        metrics: {
          lcp: {
            current_value: 4500,
            previous_value: 2000,
            threshold: 2500,
            status: 'poor'
          },
          fid: {
            current_value: 150,
            previous_value: 50,
            threshold: 100,
            status: 'needs_improvement'
          }
        },
        detected_at: Time.current.iso8601,
        url: website.url
      }
    end

    let(:webhook_signature) { generate_webhook_signature(valid_alert_payload.to_json) }

    context 'with valid webhook authentication' do
      context 'with valid payload' do
        before do
          post '/api/v1/webhooks/performance_alert',
               params: valid_alert_payload.to_json,
               headers: valid_webhook_headers
        end

        it 'returns successful response' do
          expect(response).to have_http_status(:ok)
          json_data = json_response
          expect(json_data['status']).to eq('success')
          expect(json_data['message']).to eq('Performance alert processed successfully')
        end

        it 'creates a monitoring alert' do
          alert = website.monitoring_alerts.last
          expect(alert).to be_present
          expect(alert.alert_type).to eq('performance_degradation')
          expect(alert.severity).to eq('high')
          expect(alert.message).to include('Core Web Vitals performance')
        end

        it 'stores alert metadata' do
          alert = website.monitoring_alerts.last
          expect(alert.metadata).to include('metrics')
          expect(alert.metadata['metrics']['lcp']['current_value']).to eq(4500)
        end

        it 'sends alert notifications' do
          # Assuming you have notification system
          expect {
            post '/api/v1/webhooks/performance_alert',
                 params: valid_alert_payload.to_json,
                 headers: valid_webhook_headers
          }.to have_enqueued_job # Alert notification job
        end

        it 'triggers real-time alert broadcast' do
          expect {
            post '/api/v1/webhooks/performance_alert',
                 params: valid_alert_payload.to_json,
                 headers: valid_webhook_headers
          }.to have_broadcasted_to("account_#{account.id}_alerts")
        end
      end

      context 'with duplicate alert (within time threshold)' do
        let!(:existing_alert) do
          create(:monitoring_alert, 
                 website: website, 
                 alert_type: 'performance_degradation',
                 created_at: 5.minutes.ago)
        end

        it 'returns success but does not create duplicate' do
          expect {
            post '/api/v1/webhooks/performance_alert',
                 params: valid_alert_payload.to_json,
                 headers: valid_webhook_headers
          }.not_to change(website.monitoring_alerts, :count)
          
          expect(response).to have_http_status(:ok)
          json_data = json_response
          expect(json_data['message']).to include('duplicate alert suppressed')
        end
      end

      context 'with different alert severities' do
        it 'handles critical alerts' do
          critical_payload = valid_alert_payload.merge(
            severity: 'critical',
            alert_type: 'site_down'
          )
          webhook_signature = generate_webhook_signature(critical_payload.to_json)
          
          post '/api/v1/webhooks/performance_alert',
               params: critical_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:ok)
          alert = website.monitoring_alerts.last
          expect(alert.severity).to eq('critical')
          expect(alert.alert_type).to eq('site_down')
        end
      end

      context 'with invalid payload' do
        let(:invalid_alert_payload) do
          {
            website_id: website.id,
            # Missing required fields
            detected_at: Time.current.iso8601
          }
        end
        let(:webhook_signature) { generate_webhook_signature(invalid_alert_payload.to_json) }

        it 'returns validation error' do
          post '/api/v1/webhooks/performance_alert',
               params: invalid_alert_payload.to_json,
               headers: valid_webhook_headers.merge('X-Webhook-Signature' => webhook_signature)
          
          expect(response).to have_http_status(:bad_request)
          json_data = json_response
          expect(json_data['error']).to eq('Invalid payload')
        end
      end
    end

    context 'with invalid webhook authentication' do
      it 'returns unauthorized error' do
        post '/api/v1/webhooks/performance_alert',
             params: valid_alert_payload.to_json,
             headers: invalid_webhook_headers
        
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'webhook security' do
    it 'validates request timeout' do
      # Test that old webhook requests are rejected
      old_payload = valid_payload.merge(
        timestamp: 10.minutes.ago.to_i
      )
      signature = generate_webhook_signature(old_payload.to_json)
      
      post '/api/v1/webhooks/audit_completed',
           params: old_payload.to_json,
           headers: valid_webhook_headers.merge('X-Webhook-Signature' => signature)
      
      expect(response).to have_http_status(:unauthorized)
      json_data = json_response
      expect(json_data['error']).to eq('Request timestamp too old')
    end

    it 'prevents replay attacks' do
      # First request should succeed
      post '/api/v1/webhooks/audit_completed',
           params: valid_payload.to_json,
           headers: valid_webhook_headers
      expect(response).to have_http_status(:ok)
      
      # Duplicate request with same signature should be rejected
      post '/api/v1/webhooks/audit_completed',
           params: valid_payload.to_json,
           headers: valid_webhook_headers
      expect(response).to have_http_status(:conflict)
      json_data = json_response
      expect(json_data['error']).to eq('Duplicate request detected')
    end
  end

  private

  def generate_webhook_signature(payload)
    # Simple HMAC signature generation for testing
    secret = Rails.application.credentials.webhook_secret || 'test_webhook_secret'
    OpenSSL::HMAC.hexdigest('SHA256', secret, payload)
  end
end