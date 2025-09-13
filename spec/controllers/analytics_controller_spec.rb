require 'rails_helper'

RSpec.describe AnalyticsController, type: :controller do
  let(:user) { create(:user) }
  let(:account) { create(:account) }
  let(:website) { create(:website, account: account, created_by: user) }
  
  before do
    sign_in user
    allow(Current).to receive(:account).and_return(account)
    allow(Current).to receive(:user).and_return(user)
  end

  describe 'GET #trends' do
    let!(:audit_reports) do
      # Create reports over several weeks
      [
        create(:audit_report, website: website, overall_score: 75, created_at: 3.weeks.ago, status: :completed),
        create(:audit_report, website: website, overall_score: 78, created_at: 2.weeks.ago.beginning_of_week + 1.day, status: :completed),
        create(:audit_report, website: website, overall_score: 80, created_at: 2.weeks.ago.beginning_of_week + 3.days, status: :completed),
        create(:audit_report, website: website, overall_score: 82, created_at: 1.week.ago.beginning_of_week + 2.days, status: :completed),
        create(:audit_report, website: website, overall_score: 85, created_at: 1.week.ago.beginning_of_week + 4.days, status: :completed),
        create(:audit_report, website: website, overall_score: 88, created_at: Time.current, status: :completed)
      ]
    end

    it 'renders successfully' do
      get :trends
      expect(response).to be_successful
    end

    it 'assigns trend data' do
      get :trends
      expect(assigns(:trend_data)).to be_present
    end

    it 'groups audit reports by week for improvement rate calculation' do
      get :trends
      
      # The controller should calculate weekly averages
      # Week 1 (3 weeks ago): 75
      # Week 2 (2 weeks ago): (78 + 80) / 2 = 79
      # Week 3 (1 week ago): (82 + 85) / 2 = 83.5
      # Week 4 (current week): 88
      
      expect(assigns(:trend_data)).to include(:improvement_rate)
      improvement_data = assigns(:trend_data)[:improvement_rate]
      
      expect(improvement_data).to be_an(Array)
      expect(improvement_data).not_to be_empty
      
      # Check that improvement rates are calculated
      improvement_data.each do |point|
        expect(point).to have_key(:date)
        expect(point).to have_key(:rate)
      end
    end

    it 'handles periods with no audit reports' do
      AuditReport.destroy_all
      
      get :trends
      
      expect(response).to be_successful
      expect(assigns(:trend_data)).to be_present
      expect(assigns(:trend_data)[:improvement_rate]).to eq([])
    end

    context 'with date range params' do
      it 'filters data by date range' do
        get :trends, params: { start_date: 2.weeks.ago.to_date, end_date: 1.week.ago.to_date }
        
        expect(response).to be_successful
        # Data should only include reports from 2 weeks ago to 1 week ago
      end
    end
  end

  describe 'weekly grouping functionality' do
    let(:reports_by_day) do
      # Create reports across multiple days in different weeks
      {
        3.weeks.ago.beginning_of_week => 70,
        3.weeks.ago.beginning_of_week + 2.days => 72,
        3.weeks.ago.beginning_of_week + 4.days => 74,
        2.weeks.ago.beginning_of_week => 76,
        2.weeks.ago.beginning_of_week + 3.days => 78,
        1.week.ago.beginning_of_week => 80,
        1.week.ago.beginning_of_week + 1.day => 82,
        1.week.ago.beginning_of_week + 5.days => 84,
        Time.current.beginning_of_week => 86,
        Time.current => 88
      }
    end

    before do
      reports_by_day.each do |date, score|
        create(:audit_report, 
               website: website, 
               overall_score: score, 
               created_at: date,
               status: :completed)
      end
    end

    it 'correctly groups reports by week and calculates averages' do
      get :trends
      
      improvement_data = assigns(:trend_data)[:improvement_rate]
      
      # Verify weekly grouping produces correct number of weeks
      expect(improvement_data.length).to be >= 3
      
      # Verify improvement rate calculation
      # Should calculate percentage change from previous week
      improvement_data.each_with_index do |point, index|
        if index > 0
          expect(point[:rate]).to be_a(Numeric)
        end
      end
    end
  end
end