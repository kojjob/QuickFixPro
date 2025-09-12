require 'rails_helper'

RSpec.describe MonitoringAlert, type: :model do
  describe 'associations' do
    it { should belong_to(:website) }
  end

  describe 'validations' do
    it { should validate_presence_of(:message) }  # The actual column name
    it { should validate_presence_of(:alert_type) }
    it { should validate_presence_of(:severity) }

    it 'validates title presence through alias' do
      alert = build(:monitoring_alert, message: nil)
      expect(alert).not_to be_valid
      expect(alert.errors[:message]).to include("can't be blank")
    end
  end

  describe 'constants and pseudo-enums' do
    it 'defines alert types' do
      expect(described_class::ALERT_TYPES).to eq({
        "performance_degradation" => 0,
        "availability_issue" => 1,
        "security_warning" => 2,
        "seo_issue" => 3,
        "accessibility_issue" => 4,
        "ssl_certificate_issue" => 5,
        "content_change" => 6
      })
    end

    it 'defines severities' do
      expect(described_class::SEVERITIES).to eq({
        "low" => 0,
        "medium" => 1,
        "high" => 2,
        "critical" => 3
      })
    end

    it 'validates alert_type inclusion' do
      alert = build(:monitoring_alert, alert_type: 'invalid')
      expect(alert).not_to be_valid
      expect(alert.errors[:alert_type]).to include("is not included in the list")
    end

    it 'validates severity inclusion' do
      alert = build(:monitoring_alert, severity: 'invalid')
      expect(alert).not_to be_valid
      expect(alert.errors[:severity]).to include("is not included in the list")
    end
  end

  describe 'scopes' do
    let!(:active_alert) { create(:monitoring_alert, resolved: false) }
    let!(:resolved_alert) { create(:monitoring_alert, resolved: true, resolved_at: 1.hour.ago) }
    let!(:critical_alert) { create(:monitoring_alert, severity: :critical) }
    let!(:low_alert) { create(:monitoring_alert, severity: :low) }

    describe '.active' do
      it 'returns only unresolved alerts' do
        expect(described_class.active).to include(active_alert)
        expect(described_class.active).not_to include(resolved_alert)
      end
    end

    describe '.resolved' do
      it 'returns only resolved alerts' do
        expect(described_class.resolved).to include(resolved_alert)
        expect(described_class.resolved).not_to include(active_alert)
      end
    end

    describe '.recent' do
      it 'orders alerts by created_at descending' do
        expect(described_class.recent.first).to eq(low_alert)
        expect(described_class.recent.last).to eq(active_alert)
      end
    end

    describe '.by_severity' do
      it 'orders alerts by severity descending' do
        expect(described_class.by_severity.first).to eq(critical_alert)
        expect(described_class.by_severity.last).to eq(low_alert)
      end
    end

    describe '.critical_or_high' do
      let!(:high_alert) { create(:monitoring_alert, severity: :high) }
      let!(:medium_alert) { create(:monitoring_alert, severity: :medium) }

      it 'returns only critical and high severity alerts' do
        expect(described_class.critical_or_high).to include(critical_alert, high_alert)
        expect(described_class.critical_or_high).not_to include(medium_alert, low_alert)
      end
    end
  end

  describe '#resolve!' do
    let(:alert) { create(:monitoring_alert, resolved: false, resolved_at: nil) }

    it 'marks the alert as resolved' do
      expect { alert.resolve! }.to change { alert.resolved }.from(false).to(true)
    end

    it 'sets the resolved_at timestamp' do
      freeze_time do
        alert.resolve!
        expect(alert.resolved_at).to eq(Time.current)
      end
    end
  end

  describe '#severity_color' do
    it 'returns the correct color for each severity' do
      expect(build(:monitoring_alert, severity: :critical).severity_color).to eq('red')
      expect(build(:monitoring_alert, severity: :high).severity_color).to eq('orange')
      expect(build(:monitoring_alert, severity: :medium).severity_color).to eq('yellow')
      expect(build(:monitoring_alert, severity: :low).severity_color).to eq('blue')
    end
  end

  describe '#severity_badge_class' do
    it 'returns the correct CSS classes for each severity' do
      expect(build(:monitoring_alert, severity: :critical).severity_badge_class).to eq('bg-red-100 text-red-800')
      expect(build(:monitoring_alert, severity: :high).severity_badge_class).to eq('bg-orange-100 text-orange-800')
      expect(build(:monitoring_alert, severity: :medium).severity_badge_class).to eq('bg-yellow-100 text-yellow-800')
      expect(build(:monitoring_alert, severity: :low).severity_badge_class).to eq('bg-blue-100 text-blue-800')
    end
  end

  describe 'defaults' do
    let(:alert) { MonitoringAlert.new }

    it 'sets resolved to false by default' do
      expect(alert.resolved).to eq(false)
    end

    it 'sets metadata to empty hash by default' do
      expect(alert.metadata).to eq({})
    end
  end
end
