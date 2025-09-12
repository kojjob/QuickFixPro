require 'rails_helper'

RSpec.describe 'API::V1::PerformanceMetrics', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:website) { create(:website, account: account) }
  let(:audit_report) { create(:audit_report, website: website) }
  let(:other_account) { create(:account) }
  let(:other_website) { create(:website, account: other_account) }
  let(:headers) { auth_headers_for(user) }

  describe 'GET /api/v1/websites/:website_id/performance_metrics' do
    let!(:lcp_metric) { create(:performance_metric, :lcp, audit_report: audit_report) }
    let!(:fid_metric) { create(:performance_metric, :fid, audit_report: audit_report) }
    let!(:cls_metric) { create(:performance_metric, :cls, audit_report: audit_report) }
    let!(:ttfb_metric) { create(:performance_metric, :ttfb, audit_report: audit_report) }

    # Create metrics for a different website (should not appear in results)
    let!(:other_audit) { create(:audit_report, website: other_website) }
    let!(:other_metric) { create(:performance_metric, audit_report: other_audit) }

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}/performance_metrics", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns performance metrics for the specific website' do
        json_data = json_response
        expect(json_data['performance_metrics']).to be_an(Array)
        expect(json_data['performance_metrics'].length).to eq(4)
        
        metric_types = json_data['performance_metrics'].map { |m| m['metric_type'] }
        expect(metric_types).to include('lcp', 'fid', 'cls', 'ttfb')
      end

      it 'includes proper performance metric attributes' do
        metric_data = json_response['performance_metrics'].first
        expect(metric_data).to include(
          'id', 'metric_type', 'value', 'unit', 'threshold_status',
          'display_name', 'display_value', 'threshold_color', 
          'is_core_web_vital', 'created_at'
        )
      end

      it 'includes threshold information' do
        metric_data = json_response['performance_metrics'].first
        expect(metric_data).to include(
          'threshold_good', 'threshold_poor', 'score_contribution'
        )
      end

      it 'groups core web vitals separately' do
        json_data = json_response
        expect(json_data['core_web_vitals']).to be_an(Array)
        expect(json_data['core_web_vitals'].length).to eq(3)
        
        cwv_types = json_data['core_web_vitals'].map { |m| m['metric_type'] }
        expect(cwv_types).to contain_exactly('lcp', 'fid', 'cls')
      end

      it 'groups other metrics separately' do
        json_data = json_response
        expect(json_data['other_metrics']).to be_an(Array)
        expect(json_data['other_metrics'].length).to eq(1)
        expect(json_data['other_metrics'].first['metric_type']).to eq('ttfb')
      end

      it 'includes overall performance summary' do
        json_data = json_response
        expect(json_data['summary']).to be_a(Hash)
        expect(json_data['summary']).to include(
          'total_metrics', 'good_metrics', 'needs_improvement_metrics', 
          'poor_metrics', 'average_score_impact'
        )
      end
    end

    context 'when trying to access metrics for website from different account' do
      it 'returns not found error' do
        get "/api/v1/websites/#{other_website.id}/performance_metrics", headers: headers
        expect_error_response(:not_found, 'Website not found')
      end
    end

    context 'when unauthenticated' do
      it 'returns unauthorized error' do
        get "/api/v1/websites/#{website.id}/performance_metrics"
        expect_error_response(:unauthorized, 'Authentication required')
      end
    end

    context 'with filtering parameters' do
      let!(:poor_metric) { create(:performance_metric, :lcp, :poor, audit_report: audit_report) }
      let!(:good_metric) { create(:performance_metric, :fid, audit_report: audit_report) }

      it 'filters by metric type' do
        get "/api/v1/websites/#{website.id}/performance_metrics?metric_type=lcp", headers: headers
        
        expect_success_response
        json_data = json_response
        metric_types = json_data['performance_metrics'].map { |m| m['metric_type'] }
        expect(metric_types).to all(eq('lcp'))
      end

      it 'filters by threshold status' do
        get "/api/v1/websites/#{website.id}/performance_metrics?threshold_status=poor", headers: headers
        
        expect_success_response
        json_data = json_response
        statuses = json_data['performance_metrics'].map { |m| m['threshold_status'] }
        expect(statuses).to all(eq('poor'))
      end

      it 'filters to core web vitals only' do
        get "/api/v1/websites/#{website.id}/performance_metrics?core_web_vitals_only=true", headers: headers
        
        expect_success_response
        json_data = json_response
        metric_types = json_data['performance_metrics'].map { |m| m['metric_type'] }
        expect(metric_types).to all(be_in(['lcp', 'fid', 'cls']))
      end
    end

    context 'with pagination parameters' do
      before do
        # Create additional metrics across multiple audit reports
        5.times do
          report = create(:audit_report, website: website)
          create(:performance_metric, audit_report: report)
        end
      end

      it 'respects pagination parameters' do
        get "/api/v1/websites/#{website.id}/performance_metrics?page=1&per_page=5", headers: headers
        
        expect_success_response
        json_data = json_response
        expect(json_data['performance_metrics'].length).to be <= 5
        expect(json_data['pagination']['per_page']).to eq(5)
      end
    end

    context 'with date range filtering' do
      let!(:old_audit) { create(:audit_report, website: website, created_at: 1.month.ago) }
      let!(:old_metric) { create(:performance_metric, audit_report: old_audit) }
      let!(:recent_audit) { create(:audit_report, website: website, created_at: 1.day.ago) }
      let!(:recent_metric) { create(:performance_metric, audit_report: recent_audit) }

      it 'filters by date range' do
        from_date = 1.week.ago.to_date
        to_date = Date.current
        
        get "/api/v1/websites/#{website.id}/performance_metrics?from_date=#{from_date}&to_date=#{to_date}", 
            headers: headers
        
        expect_success_response
        json_data = json_response
        
        # Should only include recent metrics, not old ones
        expect(json_data['performance_metrics']).not_to be_empty
        metric_ids = json_data['performance_metrics'].map { |m| m['id'] }
        expect(metric_ids).not_to include(old_metric.id)
      end
    end
  end

  describe 'GET /api/v1/websites/:website_id/performance_metrics/trends' do
    let!(:audit1) { create(:audit_report, website: website, created_at: 3.days.ago) }
    let!(:audit2) { create(:audit_report, website: website, created_at: 2.days.ago) }
    let!(:audit3) { create(:audit_report, website: website, created_at: 1.day.ago) }

    let!(:lcp_metrics) do
      [
        create(:performance_metric, :lcp, audit_report: audit1, value: 3000),
        create(:performance_metric, :lcp, audit_report: audit2, value: 2500),
        create(:performance_metric, :lcp, audit_report: audit3, value: 2000)
      ]
    end

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}/performance_metrics/trends", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns trend data grouped by metric type' do
        json_data = json_response
        expect(json_data['trends']).to be_a(Hash)
        expect(json_data['trends']['lcp']).to be_an(Array)
        expect(json_data['trends']['lcp'].length).to eq(3)
      end

      it 'includes trend analysis' do
        json_data = json_response
        expect(json_data['analysis']).to be_a(Hash)
        expect(json_data['analysis']['lcp']).to include(
          'trend_direction', 'improvement_percentage', 'average_value'
        )
      end

      it 'orders data points chronologically' do
        json_data = json_response
        lcp_trend = json_data['trends']['lcp']
        dates = lcp_trend.map { |point| Date.parse(point['date']) }
        expect(dates).to eq(dates.sort)
      end
    end

    context 'with specific metric type filter' do
      let!(:fid_metrics) do
        [
          create(:performance_metric, :fid, audit_report: audit1, value: 100),
          create(:performance_metric, :fid, audit_report: audit2, value: 80),
          create(:performance_metric, :fid, audit_report: audit3, value: 60)
        ]
      end

      it 'returns trends for specific metric type only' do
        get "/api/v1/websites/#{website.id}/performance_metrics/trends?metric_type=fid", headers: headers
        
        expect_success_response
        json_data = json_response
        expect(json_data['trends'].keys).to eq(['fid'])
        expect(json_data['analysis'].keys).to eq(['fid'])
      end
    end
  end

  describe 'GET /api/v1/websites/:website_id/performance_metrics/summary' do
    let!(:good_metrics) { create_list(:performance_metric, 5, audit_report: audit_report, threshold_status: :good) }
    let!(:poor_metrics) { create_list(:performance_metric, 2, audit_report: audit_report, threshold_status: :poor) }
    let!(:improvement_metrics) { create_list(:performance_metric, 3, audit_report: audit_report, threshold_status: :needs_improvement) }

    context 'when authenticated and authorized' do
      before { get "/api/v1/websites/#{website.id}/performance_metrics/summary", headers: headers }

      it 'returns successful response' do
        expect_success_response
      end

      it 'returns performance metrics summary' do
        json_data = json_response
        expect(json_data['summary']).to include(
          'total_metrics' => 10,
          'good_metrics' => 5,
          'needs_improvement_metrics' => 3,
          'poor_metrics' => 2
        )
      end

      it 'includes performance grade distribution' do
        json_data = json_response
        expect(json_data['grade_distribution']).to be_a(Hash)
        expect(json_data['grade_distribution']).to include('good', 'needs_improvement', 'poor')
      end

      it 'includes core web vitals status' do
        create(:performance_metric, :lcp, audit_report: audit_report, threshold_status: :good)
        create(:performance_metric, :fid, audit_report: audit_report, threshold_status: :good)
        create(:performance_metric, :cls, audit_report: audit_report, threshold_status: :poor)
        
        get "/api/v1/websites/#{website.id}/performance_metrics/summary", headers: headers
        
        json_data = json_response
        expect(json_data['core_web_vitals_status']).to be_a(Hash)
        expect(json_data['core_web_vitals_status']).to include('lcp', 'fid', 'cls')
        expect(json_data['core_web_vitals_status']['overall_status']).to be_present
      end

      it 'includes improvement recommendations' do
        json_data = json_response
        expect(json_data['recommendations']).to be_an(Array)
        expect(json_data['recommendations']).not_to be_empty
      end
    end

    context 'when no performance metrics exist' do
      before do
        PerformanceMetric.where(website: website).delete_all
        get "/api/v1/websites/#{website.id}/performance_metrics/summary", headers: headers
      end

      it 'returns empty summary' do
        json_data = json_response
        expect(json_data['summary']['total_metrics']).to eq(0)
        expect(json_data['recommendations']).to include('No performance data available')
      end
    end
  end
end