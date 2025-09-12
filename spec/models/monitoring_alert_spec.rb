require 'rails_helper'

RSpec.describe MonitoringAlert, type: :model do
  let(:website) { create(:website) }
  let(:monitoring_alert) { create(:monitoring_alert, website: website) }
  
  describe 'associations' do
    it { should belong_to(:website) }
  end
  
  describe 'validations' do
    describe 'alert_type' do
      it { should validate_presence_of(:alert_type) }
      
      it 'accepts valid alert types' do
        alert = build(:monitoring_alert, alert_type: :site_down)
        expect(alert).to be_valid
      end
    end
    
    describe 'severity' do
      it { should validate_presence_of(:severity) }
      
      it 'accepts valid severity levels' do
        alert = build(:monitoring_alert, severity: :critical)
        expect(alert).to be_valid
      end
    end
    
    describe 'message' do
      it { should validate_presence_of(:message) }
      
      it 'accepts valid messages' do
        alert = build(:monitoring_alert, message: 'Site is experiencing high load')
        expect(alert).to be_valid
      end
      
      it 'rejects blank messages' do
        alert = build(:monitoring_alert, message: '')
        expect(alert).not_to be_valid
        expect(alert.errors[:message]).to include("can't be blank")
      end
    end
  end
  
  describe 'enums' do
    describe 'alert_type' do
      it { should define_enum_for(:alert_type).with_values(
        performance_degradation: 0,
        site_down: 1,
        ssl_expiring: 2,
        response_time_spike: 3,
        error_rate_increase: 4
      ) }
      
      it 'can be set to different alert types' do
        expect(build(:monitoring_alert, alert_type: :performance_degradation)).to be_performance_degradation
        expect(build(:monitoring_alert, alert_type: :site_down)).to be_site_down
        expect(build(:monitoring_alert, alert_type: :ssl_expiring)).to be_ssl_expiring
        expect(build(:monitoring_alert, alert_type: :response_time_spike)).to be_response_time_spike
        expect(build(:monitoring_alert, alert_type: :error_rate_increase)).to be_error_rate_increase
      end
    end
    
    describe 'severity' do
      it { should define_enum_for(:severity).with_values(
        low: 0,
        medium: 1,
        high: 2,
        critical: 3
      ) }
      
      it 'can be set to different severity levels' do
        expect(build(:monitoring_alert, severity: :low)).to be_low
        expect(build(:monitoring_alert, severity: :medium)).to be_medium
        expect(build(:monitoring_alert, severity: :high)).to be_high
        expect(build(:monitoring_alert, severity: :critical)).to be_critical
      end
    end
  end
  
  describe 'scopes' do
    describe '.unresolved' do
      let!(:unresolved_alert) { create(:monitoring_alert, resolved: false) }
      let!(:resolved_alert) { create(:monitoring_alert, :resolved) }
      
      it 'returns only unresolved alerts' do
        expect(MonitoringAlert.unresolved).to include(unresolved_alert)
        expect(MonitoringAlert.unresolved).not_to include(resolved_alert)
      end
    end
    
    describe '.resolved' do
      let!(:unresolved_alert) { create(:monitoring_alert, resolved: false) }
      let!(:resolved_alert) { create(:monitoring_alert, :resolved) }
      
      it 'returns only resolved alerts' do
        expect(MonitoringAlert.resolved).to include(resolved_alert)
        expect(MonitoringAlert.resolved).not_to include(unresolved_alert)
      end
    end
    
    describe '.recent' do
      let!(:old_alert) { create(:monitoring_alert, created_at: 2.days.ago) }
      let!(:new_alert) { create(:monitoring_alert, created_at: 1.hour.ago) }
      let!(:newest_alert) { create(:monitoring_alert, created_at: 1.minute.ago) }
      
      it 'returns alerts ordered by most recent first' do
        alerts = MonitoringAlert.recent
        expect(alerts.first).to eq(newest_alert)
        expect(alerts.second).to eq(new_alert)
        expect(alerts.last).to eq(old_alert)
      end
    end
    
    describe '.by_severity' do
      let!(:low_alert) { create(:monitoring_alert, severity: :low) }
      let!(:medium_alert) { create(:monitoring_alert, severity: :medium) }
      let!(:high_alert) { create(:monitoring_alert, severity: :high) }
      let!(:critical_alert) { create(:monitoring_alert, severity: :critical) }
      
      it 'returns alerts ordered by severity (highest first)' do
        alerts = MonitoringAlert.by_severity
        expect(alerts.first).to eq(critical_alert)
        expect(alerts.second).to eq(high_alert)
        expect(alerts.third).to eq(medium_alert)
        expect(alerts.last).to eq(low_alert)
      end
    end
  end
  
  describe 'instance methods' do
    describe '#resolve!' do
      context 'when alert is unresolved' do
        let(:alert) { create(:monitoring_alert, resolved: false, resolved_at: nil) }
        
        it 'marks the alert as resolved' do
          expect(alert.resolved).to be false
          expect(alert.resolved_at).to be_nil
          
          time_before = Time.current
          alert.resolve!
          
          expect(alert.resolved).to be true
          expect(alert.resolved_at).to be >= time_before
          expect(alert.resolved_at).to be <= Time.current
        end
        
        it 'persists the changes' do
          alert.resolve!
          alert.reload
          
          expect(alert.resolved).to be true
          expect(alert.resolved_at).to be_present
        end
      end
      
      context 'when alert is already resolved' do
        let(:alert) { create(:monitoring_alert, :resolved) }
        let(:original_resolved_at) { alert.resolved_at }
        
        it 'updates the resolved_at timestamp' do
          original_time = alert.resolved_at
          sleep(0.01) # Ensure time difference
          alert.resolve!
          
          expect(alert.resolved).to be true
          expect(alert.resolved_at).to be >= original_time
        end
      end
    end
  end
  
  describe 'factory traits' do
    describe ':resolved trait' do
      let(:alert) { create(:monitoring_alert, :resolved) }
      
      it 'creates a resolved alert' do
        expect(alert.resolved).to be true
        expect(alert.resolved_at).to be_present
      end
    end
    
    describe 'severity traits' do
      it 'creates alerts with correct severity levels' do
        expect(create(:monitoring_alert, :critical).severity).to eq('critical')
        expect(create(:monitoring_alert, :high).severity).to eq('high')
        expect(create(:monitoring_alert, :medium).severity).to eq('medium')
        expect(create(:monitoring_alert, :low).severity).to eq('low')
      end
    end
  end
  
  describe 'alert type behaviors' do
    describe 'performance_degradation alert' do
      let(:alert) { create(:monitoring_alert, 
                          alert_type: :performance_degradation,
                          threshold_value: 80,
                          current_value: 65) }
      
      it 'has threshold and current values' do
        expect(alert.threshold_value).to eq(80)
        expect(alert.current_value).to eq(65)
        expect(alert.message).to be_present
      end
    end
    
    describe 'site_down alert' do
      let(:alert) { create(:monitoring_alert, 
                          alert_type: :site_down,
                          severity: :critical,
                          message: 'Site is not responding') }
      
      it 'typically has critical severity' do
        expect(alert.severity).to eq('critical')
        expect(alert.message).to include('not responding')
      end
    end
    
    describe 'ssl_expiring alert' do
      let(:alert) { create(:monitoring_alert, 
                          alert_type: :ssl_expiring,
                          severity: :high,
                          message: 'SSL certificate expires in 7 days') }
      
      it 'warns about SSL expiration' do
        expect(alert.alert_type).to eq('ssl_expiring')
        expect(alert.message).to include('SSL')
      end
    end
    
    describe 'response_time_spike alert' do
      let(:alert) { create(:monitoring_alert, 
                          alert_type: :response_time_spike,
                          threshold_value: 200,
                          current_value: 850) }
      
      it 'tracks response time metrics' do
        expect(alert.threshold_value).to eq(200)
        expect(alert.current_value).to eq(850)
        expect(alert.current_value).to be > alert.threshold_value
      end
    end
    
    describe 'error_rate_increase alert' do
      let(:alert) { create(:monitoring_alert, 
                          alert_type: :error_rate_increase,
                          threshold_value: 1,
                          current_value: 5.5) }
      
      it 'tracks error rate metrics' do
        expect(alert.threshold_value).to eq(1)
        expect(alert.current_value).to eq(5.5)
        expect(alert.current_value).to be > alert.threshold_value
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:website_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:alert_type).of_type(:integer) }
    it { should have_db_column(:severity).of_type(:integer) }
    it { should have_db_column(:message).of_type(:text) }
    it { should have_db_column(:threshold_value).of_type(:decimal) }
    it { should have_db_column(:current_value).of_type(:decimal) }
    it { should have_db_column(:resolved).of_type(:boolean) }
    it { should have_db_column(:resolved_at).of_type(:datetime) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:website_id) }
  end
end