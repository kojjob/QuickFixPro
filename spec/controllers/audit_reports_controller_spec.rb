require 'rails_helper'

RSpec.describe AuditReportsController, type: :controller do
  let(:user) { create(:user) }
  let(:account) { user.account }
  let(:website) { create(:website, account: account, created_by: user) }
  let(:audit_report) { create(:audit_report, website: website) }
  
  before do
    sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(Current).to receive(:account).and_return(account)
  end
  
  describe 'GET #optimizations' do
    before do
      # Create some optimization recommendations with different priorities
      create(:optimization_recommendation, website: website, priority: 0) # critical
      create(:optimization_recommendation, website: website, priority: 1) # high
      create(:optimization_recommendation, website: website, priority: 2) # medium
    end
    
    it 'assigns @optimization_recommendations' do
      get :optimizations, params: { website_id: website.id }
      expect(assigns(:optimization_recommendations)).not_to be_nil
      expect(assigns(:optimization_recommendations).count).to eq(3)
    end
    
    it 'assigns @priority_recommendations for high priority items' do
      get :optimizations, params: { website_id: website.id }
      expect(assigns(:priority_recommendations)).not_to be_nil
    end
    
    it 'assigns @optimization_stats with correct keys' do
      get :optimizations, params: { website_id: website.id }
      expect(assigns(:optimization_stats)).to have_key(:implemented)
      expect(assigns(:optimization_stats)).to have_key(:in_progress)
      expect(assigns(:optimization_stats)).to have_key(:pending)
      expect(assigns(:optimization_stats)).to have_key(:total)
    end
    
    it 'renders the optimizations template' do
      get :optimizations, params: { website_id: website.id }
      expect(response).to render_template(:optimizations)
    end
  end
  
  describe 'GET #reports' do
    it 'assigns @report_templates' do
      get :reports, params: { website_id: website.id }
      expect(assigns(:report_templates)).not_to be_nil
      expect(assigns(:report_templates)).to be_an(Array)
    end
    
    it 'assigns @recent_reports' do
      get :reports, params: { website_id: website.id }
      expect(assigns(:recent_reports)).not_to be_nil
      expect(assigns(:recent_reports)).to be_an(Array)
    end
    
    it 'assigns @report_stats' do
      get :reports, params: { website_id: website.id }
      expect(assigns(:report_stats)).not_to be_nil
      expect(assigns(:report_stats)).to have_key(:total_reports)
      expect(assigns(:report_stats)).to have_key(:this_month)
      expect(assigns(:report_stats)).to have_key(:most_popular)
      expect(assigns(:report_stats)).to have_key(:storage_used)
    end
    
    it 'assigns pagination variables' do
      get :reports, params: { website_id: website.id }
      expect(assigns(:current_page)).not_to be_nil
      expect(assigns(:per_page)).not_to be_nil
      expect(assigns(:total_reports)).not_to be_nil
      expect(assigns(:total_pages)).not_to be_nil
    end
    
    it 'renders the reports template' do
      get :reports, params: { website_id: website.id }
      expect(response).to render_template(:reports)
    end
  end
  
  describe 'GET #analytics' do
    let!(:performance_metric) do
      create(:performance_metric,
        audit_report: audit_report,
        website: website,
        metric_type: 'performance_score',
        value: 85.5
      )
    end
    
    let!(:optimization_recommendation) do
      create(:optimization_recommendation,
        website: website,
        audit_report: audit_report,
        priority: 0,
        status: 2 # completed
      )
    end
    
    before do
      audit_report.update!(status: :completed, completed_at: 1.day.ago)
    end
    
    it 'assigns @analytics_data with correct structure' do
      get :analytics, params: { website_id: website.id }
      expect(assigns(:analytics_data)).not_to be_nil
      expect(assigns(:analytics_data)).to have_key(:performance_trends)
      expect(assigns(:analytics_data)).to have_key(:core_web_vitals_trends)
      expect(assigns(:analytics_data)).to have_key(:audit_summary)
      expect(assigns(:analytics_data)).to have_key(:improvement_opportunities)
      expect(assigns(:analytics_data)).to have_key(:benchmark_comparison)
    end
    
    it 'includes all required analytics data keys' do
      get :analytics, params: { website_id: website.id }
      data = assigns(:analytics_data)
      
      # Core metrics
      expect(data).to have_key(:overall_score)
      expect(data).to have_key(:score_change)
      expect(data).to have_key(:audits_count)
      expect(data).to have_key(:websites_monitored)
      
      # Chart data
      expect(data).to have_key(:performance_trend)
      expect(data).to have_key(:time_labels)
      expect(data).to have_key(:performance_timeline)
      
      # Issue tracking
      expect(data).to have_key(:issues_resolved)
      expect(data).to have_key(:resolution_rate)
      expect(data).to have_key(:issue_categories)
      expect(data).to have_key(:top_issues)
      
      # Performance metrics
      expect(data).to have_key(:performance_gain)
      expect(data).to have_key(:avg_load_time)
      expect(data).to have_key(:score_distribution)
      
      # Audit metrics
      expect(data).to have_key(:total_audits)
      expect(data).to have_key(:audits_this_month)
      expect(data).to have_key(:weekly_audits)
      expect(data).to have_key(:next_audit_date)
      expect(data).to have_key(:score_trend)
      
      # Improvements and actions
      expect(data).to have_key(:recent_improvements)
      expect(data).to have_key(:competitive_data)
      expect(data).to have_key(:recommended_actions)
    end
    
    it 'generates issue categories with correct structure' do
      get :analytics, params: { website_id: website.id }
      categories = assigns(:analytics_data)[:issue_categories]
      
      expect(categories).to be_a(Hash)
      expect(categories).to have_key(:performance)
      expect(categories).to have_key(:accessibility)
      expect(categories).to have_key(:seo)
      expect(categories).to have_key(:best_practices)
      
      categories.each do |_, data|
        expect(data).to have_key(:count)
        expect(data).to have_key(:color)
        expect(data).to have_key(:percentage)
      end
    end
    
    it 'calculates score_change correctly' do
      get :analytics, params: { website_id: website.id }
      expect(assigns(:analytics_data)[:score_change]).to be_a(Numeric)
    end
    
    it 'generates performance_trend array' do
      get :analytics, params: { website_id: website.id }
      trend = assigns(:analytics_data)[:performance_trend]
      expect(trend).to be_an(Array)
      expect(trend.length).to eq(7)
    end
    
    it 'generates time_labels array' do
      get :analytics, params: { website_id: website.id }
      labels = assigns(:analytics_data)[:time_labels]
      expect(labels).to be_an(Array)
      expect(labels.length).to be > 0
    end
    
    it 'uses correct column names for performance_metrics' do
      get :analytics, params: { website_id: website.id }
      # This test ensures the query doesn't fail with column errors
      expect(response).to have_http_status(:success)
    end
    
    it 'renders the analytics template' do
      get :analytics, params: { website_id: website.id }
      expect(response).to render_template(:analytics)
    end
  end
  
  describe 'GET #audit_history' do
    before do
      # Create audit reports for testing
      create_list(:audit_report, 5, website: website, status: :completed, overall_score: 80)
    end
    
    it 'calculates audit frequency without using groupdate gem' do
      get :audit_history, params: { website_id: website.id }
      expect(assigns(:audit_frequency)).not_to be_nil
      expect(assigns(:audit_frequency)).to be_a(Numeric)
    end
    
    it 'renders the audit_history template' do
      get :audit_history, params: { website_id: website.id }
      expect(response).to render_template(:audit_history)
    end
  end
  
  describe 'private methods' do
    describe '#generate_detailed_performance_trends' do
      let!(:metric1) do
        create(:performance_metric,
          audit_report: audit_report,
          website: website,
          metric_type: 'performance_score',
          value: 90
        )
      end
      
      it 'uses metric_type instead of metric_name' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_detailed_performance_trends, audit_reports)
        
        expect(result).to have_key(:performance_scores)
        # The query should not raise an error about missing columns
      end
      
      it 'uses value instead of metric_value' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_detailed_performance_trends, audit_reports)
        
        expect(result[:performance_scores]).to be_an(Array)
        # The pluck should work with the correct column name
      end
    end
    
    describe '#calculate_issues_resolved' do
      let!(:resolved_recommendation) do
        create(:optimization_recommendation,
          website: website,
          status: 2 # completed
        )
      end
      
      it 'counts completed optimization recommendations' do
        audit_reports = website.audit_reports
        result = controller.send(:calculate_issues_resolved, audit_reports)
        expect(result).to eq(1)
      end
    end
    
    describe '#calculate_resolution_rate' do
      before do
        create(:optimization_recommendation, website: website, status: 0)
        create(:optimization_recommendation, website: website, status: 2)
      end
      
      it 'calculates percentage of resolved issues' do
        audit_reports = website.audit_reports
        result = controller.send(:calculate_resolution_rate, audit_reports)
        expect(result).to eq(50.0)
      end
    end
    
    describe '#generate_issue_categories' do
      it 'returns hash with correct structure' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_issue_categories, audit_reports)
        
        expect(result).to be_a(Hash)
        expect(result).to have_key(:performance)
        expect(result[:performance]).to have_key(:count)
        expect(result[:performance]).to have_key(:color)
        expect(result[:performance]).to have_key(:percentage)
      end
    end
    
    describe '#generate_top_issues' do
      it 'returns array of issue objects' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_top_issues, audit_reports)
        
        expect(result).to be_an(Array)
        expect(result.first).to have_key(:title)
        expect(result.first).to have_key(:severity)
        expect(result.first).to have_key(:impact)
      end
    end
    
    describe '#generate_competitive_data' do
      it 'returns array of competitive metrics' do
        result = controller.send(:generate_competitive_data)
        
        expect(result).to be_an(Array)
        expect(result.first).to have_key(:metric)
        expect(result.first).to have_key(:value)
        expect(result.first).to have_key(:competitor_avg)
        expect(result.first).to have_key(:status)
      end
    end
    
    describe '#generate_performance_trend' do
      it 'returns array of 7 elements' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_performance_trend, audit_reports)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(7)
      end
    end
    
    describe '#generate_time_labels' do
      it 'returns array of date labels' do
        audit_reports = website.audit_reports
        result = controller.send(:generate_time_labels, audit_reports)
        
        expect(result).to be_an(Array)
        expect(result.length).to be > 0
      end
    end
  end
end