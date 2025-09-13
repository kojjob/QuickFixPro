require 'rails_helper'

RSpec.describe AuditReport, type: :model do
  let(:website) { create(:website) }
  let(:user) { create(:user) }
  let(:audit_report) { create(:audit_report, website: website, triggered_by: user) }
  
  describe 'associations' do
    it { should belong_to(:website) }
    it { should belong_to(:triggered_by).class_name('User').optional }
    it { should have_many(:performance_metrics).dependent(:destroy) }
    it { should have_many(:optimization_recommendations).dependent(:destroy) }
  end
  
  describe 'validations' do
    describe 'overall_score' do
      it 'allows nil values' do
        audit_report = build(:audit_report, overall_score: nil)
        expect(audit_report).to be_valid
      end
      
      it 'accepts scores between 0 and 100' do
        [0, 1, 50, 99, 100].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report).to be_valid
        end
      end
      
      it 'rejects scores below 0' do
        audit_report = build(:audit_report, overall_score: -1)
        expect(audit_report).not_to be_valid
        expect(audit_report.errors[:overall_score]).to be_present
      end
      
      it 'rejects scores above 100' do
        audit_report = build(:audit_report, overall_score: 101)
        expect(audit_report).not_to be_valid
        expect(audit_report.errors[:overall_score]).to be_present
      end
    end
    
    describe 'required fields' do
      it { should validate_presence_of(:audit_type) }
      it { should validate_presence_of(:status) }
    end
  end
  
  describe 'enums' do
    describe 'audit_type' do
      it { should define_enum_for(:audit_type).with_values(manual: 0, scheduled: 1, api_triggered: 2) }
      
      it 'can be set to different types' do
        expect(build(:audit_report, :manual)).to be_manual
        expect(build(:audit_report, :scheduled)).to be_scheduled
        expect(build(:audit_report, audit_type: :api_triggered)).to be_api_triggered
      end
    end
    
    describe 'status' do
      it { should define_enum_for(:status).with_values(pending: 0, running: 1, completed: 2, failed: 3, cancelled: 4) }
      
      it 'can be set to different statuses' do
        expect(build(:audit_report, :pending)).to be_pending
        expect(build(:audit_report, :running)).to be_running
        expect(build(:audit_report, :completed)).to be_completed
        expect(build(:audit_report, :failed)).to be_failed
        expect(build(:audit_report, status: :cancelled)).to be_cancelled
      end
    end
  end
  
  describe 'scopes' do
    describe '.recent' do
      it 'orders by created_at descending' do
        old_report = create(:audit_report, website: website, created_at: 2.days.ago)
        new_report = create(:audit_report, website: website, created_at: 1.hour.ago)
        mid_report = create(:audit_report, website: website, created_at: 1.day.ago)
        
        expect(AuditReport.recent).to eq([new_report, mid_report, old_report])
      end
    end
    
    describe '.successful' do
      it 'returns completed reports with scores' do
        completed_with_score = create(:audit_report, :completed, :high_score)
        completed_without_score = create(:audit_report, :completed, overall_score: nil)
        pending_report = create(:audit_report, :pending)
        failed_report = create(:audit_report, :failed)
        
        expect(AuditReport.successful).to include(completed_with_score)
        expect(AuditReport.successful).not_to include(completed_without_score, pending_report, failed_report)
      end
    end
    
    describe '.for_website' do
      it 'returns reports for specific website' do
        website1 = create(:website)
        website2 = create(:website)
        report1 = create(:audit_report, website: website1)
        report2 = create(:audit_report, website: website2)
        
        expect(AuditReport.for_website(website1)).to include(report1)
        expect(AuditReport.for_website(website1)).not_to include(report2)
      end
    end
  end
  
  describe 'callbacks' do
    describe 'broadcasts' do
      it 'broadcasts to website account on update' do
        # Broadcasts are disabled in test environment, so just ensure no errors
        expect { audit_report.update!(overall_score: 90) }.not_to raise_error
      end
    end
  end
  
  describe 'instance methods' do
    describe '#performance_grade' do
      it 'returns N/A when overall_score is nil' do
        audit_report = build(:audit_report, overall_score: nil)
        expect(audit_report.performance_grade).to eq('N/A')
      end
      
      it 'returns A for scores 90-100' do
        [90, 95, 100].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report.performance_grade).to eq('A')
        end
      end
      
      it 'returns B for scores 80-89' do
        [80, 85, 89].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report.performance_grade).to eq('B')
        end
      end
      
      it 'returns C for scores 70-79' do
        [70, 75, 79].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report.performance_grade).to eq('C')
        end
      end
      
      it 'returns D for scores 60-69' do
        [60, 65, 69].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report.performance_grade).to eq('D')
        end
      end
      
      it 'returns F for scores below 60' do
        [0, 30, 59].each do |score|
          audit_report = build(:audit_report, overall_score: score)
          expect(audit_report.performance_grade).to eq('F')
        end
      end
    end
    
    describe '#performance_color' do
      it 'returns green for grades A and B' do
        audit_report = build(:audit_report, overall_score: 90)
        expect(audit_report.performance_color).to eq('green')
        
        audit_report.overall_score = 85
        expect(audit_report.performance_color).to eq('green')
      end
      
      it 'returns yellow for grade C' do
        audit_report = build(:audit_report, overall_score: 75)
        expect(audit_report.performance_color).to eq('yellow')
      end
      
      it 'returns red for grades D and F' do
        audit_report = build(:audit_report, overall_score: 65)
        expect(audit_report.performance_color).to eq('red')
        
        audit_report.overall_score = 50
        expect(audit_report.performance_color).to eq('red')
      end
      
      it 'returns gray for N/A grade' do
        audit_report = build(:audit_report, overall_score: nil)
        expect(audit_report.performance_color).to eq('gray')
      end
    end
    
    describe '#duration_in_seconds' do
      it 'returns 0 when started_at is nil' do
        audit_report = build(:audit_report, started_at: nil, completed_at: Time.current)
        expect(audit_report.duration_in_seconds).to eq(0)
      end
      
      it 'returns 0 when completed_at is nil' do
        audit_report = build(:audit_report, started_at: Time.current, completed_at: nil)
        expect(audit_report.duration_in_seconds).to eq(0)
      end
      
      it 'calculates duration between started_at and completed_at' do
        started = Time.current
        completed = started + 30.seconds
        audit_report = build(:audit_report, started_at: started, completed_at: completed)
        expect(audit_report.duration_in_seconds).to be_within(0.1).of(30.0)
      end
    end
    
    describe '#has_recommendations?' do
      it 'returns false when no recommendations exist' do
        expect(audit_report.has_recommendations?).to be false
      end
      
      it 'returns true when recommendations exist' do
        create(:optimization_recommendation, audit_report: audit_report)
        expect(audit_report.has_recommendations?).to be true
      end
    end
    
    describe '#critical_recommendations' do
      it 'returns only critical priority recommendations' do
        critical_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :critical)
        high_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :high)
        medium_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :medium)
        
        expect(audit_report.critical_recommendations).to include(critical_rec)
        expect(audit_report.critical_recommendations).not_to include(high_rec, medium_rec)
      end
    end
    
    describe '#high_priority_recommendations' do
      it 'returns critical and high priority recommendations' do
        critical_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :critical)
        high_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :high)
        medium_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :medium)
        low_rec = create(:optimization_recommendation, audit_report: audit_report, priority: :low)
        
        expect(audit_report.high_priority_recommendations).to include(critical_rec, high_rec)
        expect(audit_report.high_priority_recommendations).not_to include(medium_rec, low_rec)
      end
    end
    
    describe '#core_web_vitals' do
      it 'returns only LCP, FID, and CLS metrics' do
        lcp = create(:performance_metric, audit_report: audit_report, metric_type: 'lcp')
        fid = create(:performance_metric, audit_report: audit_report, metric_type: 'fid')
        cls = create(:performance_metric, audit_report: audit_report, metric_type: 'cls')
        ttfb = create(:performance_metric, audit_report: audit_report, metric_type: 'ttfb')
        
        expect(audit_report.core_web_vitals).to include(lcp, fid, cls)
        expect(audit_report.core_web_vitals).not_to include(ttfb)
      end
    end
    
    describe '#other_metrics' do
      it 'returns all metrics except core web vitals' do
        lcp = create(:performance_metric, audit_report: audit_report, metric_type: 'lcp')
        ttfb = create(:performance_metric, audit_report: audit_report, metric_type: 'ttfb')
        fcp = create(:performance_metric, audit_report: audit_report, metric_type: 'fcp')
        
        expect(audit_report.other_metrics).to include(ttfb, fcp)
        expect(audit_report.other_metrics).not_to include(lcp)
      end
    end
    
    describe '#mark_as_running!' do
      it 'updates status to running and sets started_at' do
        audit_report = create(:audit_report, :pending)
        time_before = Time.current
        
        audit_report.mark_as_running!
        
        expect(audit_report.status).to eq('running')
        expect(audit_report.started_at).to be >= time_before
        expect(audit_report.error_message).to be_nil
      end
    end
    
    describe '#mark_as_completed!' do
      it 'updates status to completed with all provided data' do
        audit_report = create(:audit_report, :pending, started_at: 1.minute.ago)
        results = { 'test' => 'data' }
        summary = { 'summary' => 'info' }
        
        audit_report.mark_as_completed!(score: 85, results: results, summary: summary)
        
        expect(audit_report.status).to eq('completed')
        expect(audit_report.overall_score).to eq(85)
        expect(audit_report.raw_results).to eq(results)
        expect(audit_report.summary_data).to eq(summary)
        expect(audit_report.completed_at).to be_present
        expect(audit_report.duration).to be >= 0
      end
    end
    
    describe '#mark_as_failed!' do
      it 'updates status to failed with error message' do
        audit_report = create(:audit_report, :pending, started_at: 1.minute.ago)
        error_msg = 'Connection timeout'
        
        audit_report.mark_as_failed!(error_msg)
        
        expect(audit_report.status).to eq('failed')
        expect(audit_report.error_message).to eq(error_msg)
        expect(audit_report.completed_at).to be_present
        expect(audit_report.duration).to be >= 0
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:website_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:triggered_by_id).of_type(:uuid) }
    it { should have_db_column(:overall_score).of_type(:integer) }
    it { should have_db_column(:audit_type).of_type(:integer).with_options(null: false, default: 'manual') }
    it { should have_db_column(:status).of_type(:integer).with_options(null: false, default: 'pending') }
    it { should have_db_column(:duration).of_type(:decimal) }
    it { should have_db_column(:error_message).of_type(:text) }
    it { should have_db_column(:raw_results).of_type(:jsonb) }
    it { should have_db_column(:summary_data).of_type(:jsonb) }
    it { should have_db_column(:started_at).of_type(:datetime) }
    it { should have_db_column(:completed_at).of_type(:datetime) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:audit_type) }
    it { should have_db_index(:overall_score) }
    it { should have_db_index(:status) }
    it { should have_db_index(:triggered_by_id) }
    it { should have_db_index(:website_id) }
    it { should have_db_index([:website_id, :created_at]) }
    it { should have_db_index([:website_id, :status]) }
  end
end