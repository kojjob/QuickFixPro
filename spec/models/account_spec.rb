require 'rails_helper'

RSpec.describe Account, type: :model do
  describe 'associations' do
    it { should have_many(:users).dependent(:destroy) }
    it { should have_many(:websites).dependent(:destroy) }
    it { should have_many(:subscriptions).dependent(:destroy) }
    it { should have_many(:audit_reports).through(:websites) }
    it { should belong_to(:created_by).class_name('User').optional }
  end

  describe 'validations' do
    subject { build(:account, subdomain: 'test-account') }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    
    it { should validate_presence_of(:subdomain) }
    it { should validate_uniqueness_of(:subdomain).case_insensitive }
    it { should validate_length_of(:subdomain).is_at_least(3).is_at_most(63) }
    
    describe 'subdomain format' do
      it 'allows valid subdomains' do
        valid_subdomains = ['test', 'test-123', 'abc123', 'company-name']
        valid_subdomains.each do |subdomain|
          account = build(:account, subdomain: subdomain)
          expect(account).to be_valid
        end
      end

      it 'rejects invalid subdomains' do
        # Remove 'Test' since it's normalized to 'test' and becomes valid
        invalid_subdomains = ['test_123', 'test.com', 'test@123', 'test 123', 'test!']
        invalid_subdomains.each do |subdomain|
          account = build(:account, subdomain: subdomain)
          expect(account).not_to be_valid
          expect(account.errors[:subdomain]).to include('can only contain lowercase letters, numbers, and hyphens')
        end
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(trial: 0, active: 1, suspended: 2, cancelled: 3) }
  end

  describe 'callbacks' do
    describe '#normalize_subdomain' do
      it 'downcases and strips the subdomain before validation' do
        account = build(:account, subdomain: '  TEST-SUBDOMAIN  ')
        account.valid?
        expect(account.subdomain).to eq('test-subdomain')
      end

      it 'handles nil subdomain gracefully' do
        account = build(:account, subdomain: nil)
        expect { account.valid? }.not_to raise_error
      end
    end
  end

  describe 'scopes' do
    describe '.active_accounts' do
      let!(:trial_account) { create(:account, status: :trial) }
      let!(:active_account) { create(:account, status: :active) }
      let!(:suspended_account) { create(:account, status: :suspended) }
      let!(:cancelled_account) { create(:account, status: :cancelled) }

      it 'returns only trial and active accounts' do
        expect(Account.active_accounts).to contain_exactly(trial_account, active_account)
      end
    end
  end

  describe 'instance methods' do
    describe '#display_name' do
      it 'returns the name when present' do
        account = build(:account, name: 'Company Inc', subdomain: 'company')
        expect(account.display_name).to eq('Company Inc')
      end

      it 'returns humanized subdomain when name is blank' do
        account = build(:account, name: '', subdomain: 'company-name')
        expect(account.display_name).to eq('Company-name')
      end

      it 'returns humanized subdomain when name is nil' do
        account = build(:account, name: nil, subdomain: 'test-subdomain')
        expect(account.display_name).to eq('Test-subdomain')
      end
    end

    describe '#trial_expired?' do
      context 'when account is in trial status' do
        it 'returns true if created more than 14 days ago' do
          account = create(:account, status: :trial, created_at: 15.days.ago)
          expect(account.trial_expired?).to be true
        end

        it 'returns false if created less than 14 days ago' do
          account = create(:account, status: :trial, created_at: 13.days.ago)
          expect(account.trial_expired?).to be false
        end

        it 'returns true if created exactly 14 days ago' do
          account = create(:account, status: :trial, created_at: 14.days.ago)
          expect(account.trial_expired?).to be true
        end
      end

      context 'when account is not in trial status' do
        it 'returns false for active accounts' do
          account = create(:account, status: :active, created_at: 20.days.ago)
          expect(account.trial_expired?).to be false
        end

        it 'returns false for suspended accounts' do
          account = create(:account, status: :suspended, created_at: 20.days.ago)
          expect(account.trial_expired?).to be false
        end
      end
    end

    describe '#current_subscription' do
      let(:account) { create(:account) }

      context 'when account has active subscriptions' do
        let!(:active_subscription) { create(:subscription, account: account, status: :active) }
        let!(:cancelled_subscription) { create(:subscription, account: account, status: :cancelled) }

        it 'returns the first active subscription' do
          expect(account.current_subscription).to eq(active_subscription)
        end
      end

      context 'when account has trial subscription' do
        let!(:trial_subscription) { create(:subscription, account: account, status: :trial) }

        it 'returns the trial subscription' do
          expect(account.current_subscription).to eq(trial_subscription)
        end
      end

      context 'when account has no active subscriptions' do
        let!(:cancelled_subscription) { create(:subscription, account: account, status: :cancelled) }

        it 'returns nil' do
          expect(account.current_subscription).to be_nil
        end
      end

      context 'when account has no subscriptions' do
        it 'returns nil' do
          expect(account.current_subscription).to be_nil
        end
      end
    end

    describe '#subscription' do
      let(:account) { create(:account) }
      let!(:active_subscription) { create(:subscription, account: account, status: :active) }

      it 'is an alias for current_subscription' do
        expect(account.subscription).to eq(account.current_subscription)
      end
    end

    describe '#within_usage_limits?' do
      let(:account) { create(:account) }

      context 'when account has no subscription' do
        it 'returns false' do
          expect(account.within_usage_limits?('websites')).to be false
        end
      end

      context 'when account has an active subscription' do
        context 'with starter plan' do
          let!(:subscription) { create(:subscription, :starter, account: account, status: :active) }

          it 'returns true when current usage is below the limit' do
            expect(account.within_usage_limits?('websites', 4)).to be true
          end

          it 'returns false when current usage equals the limit' do
            expect(account.within_usage_limits?('websites', 5)).to be false
          end

          it 'returns false when current usage exceeds the limit' do
            expect(account.within_usage_limits?('websites', 6)).to be false
          end

          it 'returns false when feature limit is not defined' do
            expect(account.within_usage_limits?('undefined_feature')).to be false
          end

          it 'handles symbol feature names' do
            expect(account.within_usage_limits?(:websites, 3)).to be true
          end

          it 'defaults to 0 current usage when not provided' do
            expect(account.within_usage_limits?('websites')).to be true
          end
        end

        context 'with enterprise plan (unlimited features)' do
          let!(:subscription) { create(:subscription, :enterprise, account: account, status: :active) }

          it 'returns true for unlimited features (limit = -1)' do
            expect(account.within_usage_limits?('websites', 1000)).to be true
          end
        end
      end
    end
  end

  describe 'database columns' do
    it { should have_db_column(:id).of_type(:uuid) }
    it { should have_db_column(:name).of_type(:string) }
    it { should have_db_column(:subdomain).of_type(:string) }
    it { should have_db_column(:status).of_type(:integer).with_options(default: 'trial') }
    it { should have_db_column(:created_by_id).of_type(:uuid) }
    it { should have_db_column(:settings).of_type(:jsonb).with_options(default: {}) }
    it { should have_db_column(:description).of_type(:text) }
    it { should have_db_column(:stripe_customer_id).of_type(:string) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'indexes' do
    it { should have_db_index(:created_by_id) }
    it { should have_db_index(:settings) }
    it { should have_db_index(:status) }
    it { should have_db_index(:stripe_customer_id).unique }
    it { should have_db_index(:subdomain).unique }
  end
end
