require 'rails_helper'

RSpec.describe Website, type: :model do
  describe 'concerns' do
    it 'includes AccountOwnable' do
      expect(Website.ancestors).to include(AccountOwnable)
    end
  end

  describe 'associations' do
    it { should belong_to(:account) }
    it { should belong_to(:created_by).class_name('User') }
    it { should have_many(:audit_reports).dependent(:destroy) }
    it { should have_many(:performance_metrics).through(:audit_reports) }
    it { should have_many(:optimization_recommendations).through(:audit_reports) }
    it { should have_many(:monitoring_alerts).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:website) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:url) }
    it { should validate_presence_of(:account) }
    
    describe 'url format' do
      it 'accepts valid URLs' do
        valid_urls = ['http://example.com', 'https://example.com', 'https://www.example.com']
        valid_urls.each do |url|
          website = build(:website, url: url)
          expect(website).to be_valid
        end
      end
      
      it 'rejects invalid URLs' do
        # Note: 'not-a-url' gets https:// prefixed and becomes valid
        # Only test URLs that are truly invalid even after normalization
        invalid_urls = ['ftp://example.com', '//example.com', 'javascript:alert(1)']
        invalid_urls.each do |url|
          website = build(:website, url: url)
          expect(website).not_to be_valid
        end
      end
    end
    
    describe 'url uniqueness' do
      let(:account) { create(:account) }
      let!(:existing_website) { create(:website, url: 'https://example.com', account: account) }
      
      it 'validates uniqueness within the same account' do
        new_website = build(:website, url: 'https://example.com', account: account)
        expect(new_website).not_to be_valid
        expect(new_website.errors[:url]).to include('is already being monitored in this account')
      end
      
      it 'allows same URL in different accounts' do
        other_account = create(:account)
        new_website = build(:website, url: 'https://example.com', account: other_account)
        expect(new_website).to be_valid
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(active: 0, paused: 1, archived: 2).with_default(:active) }
    it { should define_enum_for(:monitoring_frequency).with_values(manual: 0, daily: 1, weekly: 2, monthly: 3) }
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_website) { create(:website, :active) }
      let!(:paused_website) { create(:website, :paused) }
      let!(:archived_website) { create(:website, :archived) }
      
      it 'returns only active websites' do
        expect(Website.active).to contain_exactly(active_website)
      end
    end
    
    describe '.recent' do
      let!(:old_website) { create(:website, created_at: 2.days.ago) }
      let!(:new_website) { create(:website, created_at: 1.hour.ago) }
      let!(:middle_website) { create(:website, created_at: 1.day.ago) }
      
      it 'returns websites ordered by creation date descending' do
        expect(Website.recent).to eq([new_website, middle_website, old_website])
      end
    end
    
    describe '.publicly_visible' do
      let!(:public_website) { create(:website, :public) }
      let!(:private_website) { create(:website, public_showcase: false) }
      
      it 'returns only publicly visible websites' do
        expect(Website.publicly_visible).to contain_exactly(public_website)
      end
    end
    
    describe '.active_monitoring' do
      let!(:manual_website) { create(:website, :manual) }
      let!(:daily_website) { create(:website, :daily) }
      let!(:weekly_website) { create(:website, :weekly) }
      let!(:paused_daily) { create(:website, :paused, :daily) }
      
      it 'returns active websites with automated monitoring' do
        expect(Website.active_monitoring).to contain_exactly(daily_website, weekly_website)
      end
    end
    
    describe '.due_for_monitoring' do
      let!(:never_monitored) { create(:website, :daily, last_monitored_at: nil) }
      let!(:overdue_daily) { create(:website, :overdue_daily) }
      let!(:recent_daily) { create(:website, :daily, last_monitored_at: 1.hour.ago) }
      let!(:manual_website) { create(:website, :manual) }
      
      it 'returns websites that need monitoring' do
        expect(Website.due_for_monitoring).to contain_exactly(never_monitored, overdue_daily)
      end
    end
    
    describe '.by_score_range' do
      let!(:high_score) { create(:website, current_score: 95) }
      let!(:medium_score) { create(:website, current_score: 75) }
      let!(:low_score) { create(:website, current_score: 45) }
      let!(:no_score) { create(:website, current_score: nil) }
      
      it 'returns websites within score range' do
        expect(Website.by_score_range(70, 100)).to contain_exactly(high_score, medium_score)
      end
      
      it 'uses 100 as default max' do
        expect(Website.by_score_range(70)).to contain_exactly(high_score, medium_score)
      end
    end
  end

  describe 'callbacks' do
    describe '#normalize_url' do
      it 'strips whitespace from URL' do
        website = build(:website, url: '  https://example.com  ')
        website.valid?
        expect(website.url).to eq('https://example.com')
      end
      
      it 'adds https:// if no protocol specified' do
        website = build(:website, url: 'example.com')
        website.valid?
        expect(website.url).to eq('https://example.com')
      end
      
      it 'preserves http:// protocol' do
        website = build(:website, url: 'http://example.com')
        website.valid?
        expect(website.url).to eq('http://example.com')
      end
    end
  end

  describe 'instance methods' do
    let(:website) { build(:website, url: 'https://www.example.com/path') }
    
    describe '#display_url' do
      it 'returns the host portion of the URL' do
        expect(website.display_url).to eq('www.example.com')
      end
      
      it 'handles invalid URLs gracefully' do
        website.url = 'not-a-valid-url'
        expect(website.display_url).to eq('not-a-valid-url')
      end
    end
    
    describe '#performance_grade' do
      it 'returns A for scores 90-100' do
        website.current_score = 95
        expect(website.performance_grade).to eq('A')
      end
      
      it 'returns B for scores 80-89' do
        website.current_score = 85
        expect(website.performance_grade).to eq('B')
      end
      
      it 'returns C for scores 70-79' do
        website.current_score = 75
        expect(website.performance_grade).to eq('C')
      end
      
      it 'returns D for scores 60-69' do
        website.current_score = 65
        expect(website.performance_grade).to eq('D')
      end
      
      it 'returns F for scores below 60' do
        website.current_score = 45
        expect(website.performance_grade).to eq('F')
      end
      
      it 'returns N/A when no score' do
        website.current_score = nil
        expect(website.performance_grade).to eq('N/A')
      end
    end
    
    describe '#performance_color' do
      it 'returns green for grades A and B' do
        website.current_score = 95
        expect(website.performance_color).to eq('green')
        
        website.current_score = 85
        expect(website.performance_color).to eq('green')
      end
      
      it 'returns yellow for grade C' do
        website.current_score = 75
        expect(website.performance_color).to eq('yellow')
      end
      
      it 'returns red for grades D and F' do
        website.current_score = 65
        expect(website.performance_color).to eq('red')
        
        website.current_score = 45
        expect(website.performance_color).to eq('red')
      end
      
      it 'returns gray for no score' do
        website.current_score = nil
        expect(website.performance_color).to eq('gray')
      end
    end
    
    describe '#should_monitor?' do
      it 'returns true for active websites with automated monitoring that are overdue' do
        website = create(:website, :active, :overdue_daily)
        expect(website.should_monitor?).to be true
      end
      
      it 'returns true for active websites with automated monitoring never monitored' do
        website = create(:website, :active, :daily, last_monitored_at: nil)
        expect(website.should_monitor?).to be true
      end
      
      it 'returns false for manual monitoring' do
        website = create(:website, :active, :manual)
        expect(website.should_monitor?).to be false
      end
      
      it 'returns false for paused websites' do
        website = create(:website, :paused, :daily)
        expect(website.should_monitor?).to be false
      end
      
      it 'returns false for recently monitored websites' do
        website = create(:website, :active, :daily, last_monitored_at: 1.hour.ago)
        expect(website.should_monitor?).to be false
      end
    end
    
    describe '#monitoring_overdue?' do
      context 'daily monitoring' do
        let(:website) { build(:website, :daily) }
        
        it 'returns true when last monitored over 1 day ago' do
          website.last_monitored_at = 2.days.ago
          expect(website.monitoring_overdue?).to be true
        end
        
        it 'returns false when monitored within 1 day' do
          website.last_monitored_at = 12.hours.ago
          expect(website.monitoring_overdue?).to be false
        end
      end
      
      context 'weekly monitoring' do
        let(:website) { build(:website, :weekly) }
        
        it 'returns true when last monitored over 1 week ago' do
          website.last_monitored_at = 8.days.ago
          expect(website.monitoring_overdue?).to be true
        end
        
        it 'returns false when monitored within 1 week' do
          website.last_monitored_at = 6.days.ago
          expect(website.monitoring_overdue?).to be false
        end
      end
      
      context 'monthly monitoring' do
        let(:website) { build(:website, :monthly) }
        
        it 'returns true when last monitored over 1 month ago' do
          website.last_monitored_at = 32.days.ago
          expect(website.monitoring_overdue?).to be true
        end
        
        it 'returns false when monitored within 1 month' do
          website.last_monitored_at = 25.days.ago
          expect(website.monitoring_overdue?).to be false
        end
      end
      
      context 'manual monitoring' do
        let(:website) { build(:website, :manual) }
        
        it 'always returns false' do
          website.last_monitored_at = 1.year.ago
          expect(website.monitoring_overdue?).to be false
        end
      end
      
      it 'returns false when never monitored' do
        website = build(:website, last_monitored_at: nil)
        expect(website.monitoring_overdue?).to be false
      end
    end
    
    describe '#latest_audit_report' do
      let(:website) { create(:website) }
      
      it 'returns the most recent audit report' do
        old_report = create(:audit_report, website: website, created_at: 2.days.ago)
        new_report = create(:audit_report, website: website, created_at: 1.hour.ago)
        middle_report = create(:audit_report, website: website, created_at: 1.day.ago)
        
        expect(website.latest_audit_report).to eq(new_report)
      end
      
      it 'returns nil when no audit reports' do
        expect(website.latest_audit_report).to be_nil
      end
    end
    
    describe '#audit_history_data' do
      let(:website) { create(:website) }
      
      it 'returns audit data for the specified period' do
        create(:audit_report, website: website, overall_score: 85, created_at: 5.days.ago)
        create(:audit_report, website: website, overall_score: 90, created_at: 2.days.ago)
        create(:audit_report, website: website, overall_score: 95, created_at: 1.day.ago)
        
        data = website.audit_history_data(limit: 7)
        expect(data.length).to eq(3)
        expect(data.first[:y]).to eq(85)
        expect(data.last[:y]).to eq(95)
      end
      
      it 'excludes audits outside the limit period' do
        create(:audit_report, website: website, overall_score: 80, created_at: 35.days.ago)
        create(:audit_report, website: website, overall_score: 90, created_at: 10.days.ago)
        
        data = website.audit_history_data(limit: 30)
        expect(data.length).to eq(1)
        expect(data.first[:y]).to eq(90)
      end
      
      it 'returns data in correct format' do
        report = create(:audit_report, website: website, overall_score: 85, created_at: 1.day.ago)
        
        data = website.audit_history_data
        expect(data.first).to have_key(:x)
        expect(data.first).to have_key(:y)
        expect(data.first[:x]).to be_a(ActiveSupport::TimeWithZone)
        expect(data.first[:y]).to eq(85)
      end
    end
    
    describe '#update_current_score!' do
      let(:website) { create(:website) }
      
      it 'updates the current score and last monitored timestamp' do
        freeze_time do
          website.update_current_score!(85)
          
          expect(website.current_score).to eq(85)
          expect(website.last_monitored_at).to eq(Time.current)
        end
      end
    end
  end

  describe 'database columns' do
    it { should have_db_column(:id).of_type(:uuid) }
    it { should have_db_column(:name).of_type(:string).with_options(null: false) }
    it { should have_db_column(:url).of_type(:string).with_options(null: false) }
    it { should have_db_column(:status).of_type(:integer).with_options(default: 'active', null: false) }
    it { should have_db_column(:monitoring_frequency).of_type(:integer).with_options(default: 'manual', null: false) }
    it { should have_db_column(:current_score).of_type(:integer) }
    it { should have_db_column(:last_monitored_at).of_type(:datetime) }
    it { should have_db_column(:public_showcase).of_type(:boolean).with_options(default: false, null: false) }
    it { should have_db_column(:monitoring_settings).of_type(:jsonb).with_options(default: {}) }
    it { should have_db_column(:notification_settings).of_type(:jsonb).with_options(default: {}) }
    it { should have_db_column(:alerts_enabled).of_type(:boolean).with_options(default: true) }
    it { should have_db_column(:description).of_type(:text) }
    it { should have_db_column(:account_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:created_by_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'indexes' do
    it { should have_db_index(:account_id) }
    it { should have_db_index(:created_by_id) }
    it { should have_db_index([:account_id, :url]).unique }
    it { should have_db_index(:monitoring_frequency) }
    it { should have_db_index(:public_showcase) }
  end
end