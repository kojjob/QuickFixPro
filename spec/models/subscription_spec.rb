require 'rails_helper'

RSpec.describe Subscription, type: :model do
  let(:account) { create(:account) }
  let(:subscription) { create(:subscription, account: account) }
  
  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:payments).dependent(:destroy) }
  end
  
  describe 'validations' do
    describe 'plan_name' do
      it { should validate_presence_of(:plan_name) }
      
      it 'accepts valid plan names' do
        %w[starter professional enterprise].each do |plan|
          subscription = build(:subscription, plan_name: plan)
          expect(subscription).to be_valid
        end
      end
      
      it 'rejects invalid plan names' do
        subscription = build(:subscription, plan_name: 'invalid_plan')
        expect(subscription).not_to be_valid
        expect(subscription.errors[:plan_name]).to be_present
      end
    end
    
    describe 'status' do
      it { should validate_presence_of(:status) }
    end
    
    describe 'monthly_price' do
      it { should validate_presence_of(:monthly_price) }
      it { should validate_numericality_of(:monthly_price).is_greater_than_or_equal_to(0) }
      
      it 'accepts zero price' do
        subscription = build(:subscription, monthly_price: 0)
        expect(subscription).to be_valid
      end
      
      it 'rejects negative price' do
        # Create a subscription first to avoid the set_plan_defaults callback
        subscription = create(:subscription)
        subscription.monthly_price = -1
        expect(subscription).not_to be_valid
        expect(subscription.errors[:monthly_price]).to include("must be greater than or equal to 0")
      end
    end
  end
  
  describe 'enums' do
    it { should define_enum_for(:status).with_values(
      trial: 0,
      active: 1,
      past_due: 2,
      cancelled: 3,
      expired: 4
    ).with_prefix(:subscription) }
    
    it 'has prefixed status methods' do
      subscription = create(:subscription, status: :trial)
      expect(subscription).to be_subscription_trial
      
      subscription.update(status: :active)
      expect(subscription).to be_subscription_active
    end
  end
  
  describe 'constants' do
    describe 'PLAN_LIMITS' do
      it 'defines limits for all plans' do
        expect(Subscription::PLAN_LIMITS).to have_key('starter')
        expect(Subscription::PLAN_LIMITS).to have_key('professional')
        expect(Subscription::PLAN_LIMITS).to have_key('enterprise')
      end
      
      it 'defines correct starter limits' do
        limits = Subscription::PLAN_LIMITS['starter']
        expect(limits[:websites]).to eq(5)
        expect(limits[:monthly_audits]).to eq(100)
        expect(limits[:users]).to eq(2)
        expect(limits[:support_level]).to eq('email')
      end
      
      it 'defines correct professional limits' do
        limits = Subscription::PLAN_LIMITS['professional']
        expect(limits[:websites]).to eq(25)
        expect(limits[:monthly_audits]).to eq(500)
        expect(limits[:users]).to eq(10)
        expect(limits[:support_level]).to eq('priority')
      end
      
      it 'defines unlimited enterprise limits' do
        limits = Subscription::PLAN_LIMITS['enterprise']
        expect(limits[:websites]).to eq(-1)
        expect(limits[:monthly_audits]).to eq(-1)
        expect(limits[:users]).to eq(-1)
        expect(limits[:support_level]).to eq('dedicated')
      end
    end
    
    describe 'PLAN_PRICES' do
      it 'defines prices for all plans' do
        expect(Subscription::PLAN_PRICES['starter']).to eq(29.00)
        expect(Subscription::PLAN_PRICES['professional']).to eq(99.00)
        expect(Subscription::PLAN_PRICES['enterprise']).to eq(299.00)
      end
    end
  end
  
  describe 'scopes' do
    describe '.active' do
      it 'returns trial and active subscriptions' do
        trial_sub = create(:subscription, status: :trial)
        active_sub = create(:subscription, status: :active)
        past_due_sub = create(:subscription, status: :past_due)
        cancelled_sub = create(:subscription, status: :cancelled)
        
        expect(Subscription.active).to include(trial_sub, active_sub)
        expect(Subscription.active).not_to include(past_due_sub, cancelled_sub)
      end
    end
    
    describe '.billable' do
      it 'returns only active subscriptions' do
        trial_sub = create(:subscription, status: :trial)
        active_sub = create(:subscription, status: :active)
        past_due_sub = create(:subscription, status: :past_due)
        
        expect(Subscription.billable).to include(active_sub)
        expect(Subscription.billable).not_to include(trial_sub, past_due_sub)
      end
    end
    
    describe '.by_plan' do
      it 'returns subscriptions for specific plan' do
        starter = create(:subscription, plan_name: 'starter')
        professional = create(:subscription, plan_name: 'professional')
        
        expect(Subscription.by_plan('starter')).to include(starter)
        expect(Subscription.by_plan('starter')).not_to include(professional)
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_validation' do
      it 'sets plan defaults when plan_name changes' do
        subscription = build(:subscription, plan_name: 'professional')
        subscription.valid?
        
        expect(subscription.monthly_price).to eq(99.00)
        expect(subscription.usage_limits['websites']).to eq(25)
      end
    end
    
    describe 'before_create' do
      it 'sets trial period for trial subscriptions' do
        subscription = build(:subscription, status: :trial, trial_ends_at: nil)
        subscription.save!
        
        expect(subscription.trial_ends_at).to be_present
        expect(subscription.trial_ends_at).to be > Time.current
      end
      
      it 'does not override existing trial_ends_at' do
        ends_at = 7.days.from_now
        subscription = build(:subscription, status: :trial, trial_ends_at: ends_at)
        subscription.save!
        
        expect(subscription.trial_ends_at).to be_within(1.second).of(ends_at)
      end
    end
  end
  
  describe 'instance methods' do
    describe '#plan_limits' do
      it 'returns limits for current plan' do
        subscription = build(:subscription, plan_name: 'starter')
        limits = subscription.plan_limits
        
        expect(limits[:websites]).to eq(5)
        expect(limits[:monthly_audits]).to eq(100)
      end
      
      it 'returns empty hash for invalid plan' do
        subscription = build(:subscription)
        subscription.plan_name = 'invalid'
        
        expect(subscription.plan_limits).to eq({})
      end
    end
    
    describe '#usage_limit_for' do
      it 'returns limit for specific feature' do
        subscription = build(:subscription, plan_name: 'starter')
        expect(subscription.usage_limit_for(:websites)).to eq(5)
      end
      
      it 'returns infinity for unlimited features' do
        subscription = build(:subscription, plan_name: 'enterprise')
        expect(subscription.usage_limit_for(:websites)).to eq(Float::INFINITY)
      end
      
      it 'returns 0 for undefined features' do
        subscription = build(:subscription, plan_name: 'starter')
        expect(subscription.usage_limit_for(:undefined_feature)).to eq(0)
      end
    end
    
    describe '#current_usage_for' do
      it 'returns usage for specific feature' do
        subscription = build(:subscription, current_usage: { 'websites' => 3 })
        expect(subscription.current_usage_for(:websites)).to eq(3)
      end
      
      it 'returns 0 for unused features' do
        subscription = build(:subscription, current_usage: {})
        expect(subscription.current_usage_for(:websites)).to eq(0)
      end
    end
    
    describe '#usage_percentage_for' do
      it 'calculates percentage for used features' do
        subscription = build(:subscription, 
          plan_name: 'starter',
          current_usage: { 'websites' => 3 }
        )
        expect(subscription.usage_percentage_for(:websites)).to eq(60.0)
      end
      
      it 'returns 0 for unlimited features' do
        subscription = build(:subscription, 
          plan_name: 'enterprise',
          current_usage: { 'websites' => 100 }
        )
        expect(subscription.usage_percentage_for(:websites)).to eq(0)
      end
      
      it 'returns 0 for undefined features' do
        subscription = build(:subscription, plan_name: 'starter')
        expect(subscription.usage_percentage_for(:undefined)).to eq(0)
      end
      
      it 'handles zero limits' do
        subscription = build(:subscription)
        allow(subscription).to receive(:usage_limit_for).and_return(0)
        expect(subscription.usage_percentage_for(:feature)).to eq(0)
      end
    end
    
    describe '#within_limit?' do
      it 'returns true when within limit' do
        subscription = build(:subscription, 
          plan_name: 'starter',
          current_usage: { 'websites' => 3 }
        )
        expect(subscription.within_limit?(:websites)).to be true
        expect(subscription.within_limit?(:websites, 1)).to be true
      end
      
      it 'returns false when exceeding limit' do
        subscription = build(:subscription, 
          plan_name: 'starter',
          current_usage: { 'websites' => 5 }
        )
        expect(subscription.within_limit?(:websites, 1)).to be false
      end
      
      it 'returns true for unlimited features' do
        subscription = build(:subscription, 
          plan_name: 'enterprise',
          current_usage: { 'websites' => 1000 }
        )
        expect(subscription.within_limit?(:websites, 1000)).to be true
      end
    end
    
    describe '#increment_usage!' do
      it 'increments usage for feature' do
        subscription = create(:subscription, current_usage: { 'websites' => 2 })
        subscription.increment_usage!(:websites)
        
        expect(subscription.current_usage_for(:websites)).to eq(3)
      end
      
      it 'increments by specified amount' do
        subscription = create(:subscription, current_usage: { 'api_requests' => 100 })
        subscription.increment_usage!(:api_requests, 50)
        
        expect(subscription.current_usage_for(:api_requests)).to eq(150)
      end
      
      it 'initializes usage for new features' do
        subscription = create(:subscription, current_usage: {})
        subscription.increment_usage!(:websites, 2)
        
        expect(subscription.current_usage_for(:websites)).to eq(2)
      end
    end
    
    describe '#reset_usage!' do
      it 'resets all usage and updates billing cycle' do
        subscription = create(:subscription, 
          current_usage: { 'websites' => 5, 'api_requests' => 1000 },
          billing_cycle_started_at: 30.days.ago
        )
        
        time_before = Time.current
        subscription.reset_usage!
        
        expect(subscription.current_usage).to eq({})
        expect(subscription.billing_cycle_started_at).to be >= time_before
      end
    end
    
    describe '#trial_active?' do
      it 'returns true for active trials' do
        subscription = build(:subscription, 
          status: :trial,
          trial_ends_at: 7.days.from_now
        )
        expect(subscription.trial_active?).to be true
      end
      
      it 'returns false for expired trials' do
        subscription = build(:subscription, 
          status: :trial,
          trial_ends_at: 1.day.ago
        )
        expect(subscription.trial_active?).to be false
      end
      
      it 'returns false for non-trial subscriptions' do
        subscription = build(:subscription, 
          status: :active,
          trial_ends_at: 7.days.from_now
        )
        expect(subscription.trial_active?).to be false
      end
    end
    
    describe '#trial_expired?' do
      it 'returns true for expired trials' do
        subscription = build(:subscription, 
          status: :trial,
          trial_ends_at: 1.day.ago
        )
        expect(subscription.trial_expired?).to be true
      end
      
      it 'returns false for active trials' do
        subscription = build(:subscription, 
          status: :trial,
          trial_ends_at: 7.days.from_now
        )
        expect(subscription.trial_expired?).to be false
      end
    end
    
    describe '#days_until_trial_expires' do
      it 'returns days remaining for active trial' do
        subscription = build(:subscription, 
          status: :trial,
          trial_ends_at: 7.days.from_now
        )
        expect(subscription.days_until_trial_expires).to eq(7)
      end
      
      it 'returns 0 for expired or non-trial' do
        subscription = build(:subscription, 
          status: :active,
          trial_ends_at: 7.days.from_now
        )
        expect(subscription.days_until_trial_expires).to eq(0)
      end
    end
    
    describe '#can_upgrade_to?' do
      it 'allows upgrades to higher plans' do
        subscription = build(:subscription, plan_name: 'starter')
        expect(subscription.can_upgrade_to?('professional')).to be true
        expect(subscription.can_upgrade_to?('enterprise')).to be true
      end
      
      it 'prevents downgrades' do
        subscription = build(:subscription, plan_name: 'professional')
        expect(subscription.can_upgrade_to?('starter')).to be false
      end
      
      it 'prevents same plan changes' do
        subscription = build(:subscription, plan_name: 'professional')
        expect(subscription.can_upgrade_to?('professional')).to be false
      end
      
      it 'rejects invalid plans' do
        subscription = build(:subscription, plan_name: 'starter')
        expect(subscription.can_upgrade_to?('invalid')).to be false
      end
    end
    
    describe '#upgrade_to!' do
      it 'upgrades to higher plan' do
        subscription = create(:subscription, plan_name: 'starter')
        result = subscription.upgrade_to!('professional')
        
        expect(result).to be true
        expect(subscription.plan_name).to eq('professional')
        expect(subscription.monthly_price).to eq(99.00)
        expect(subscription.usage_limits['websites']).to eq(25)
      end
      
      it 'returns false for invalid upgrades' do
        subscription = create(:subscription, plan_name: 'professional')
        result = subscription.upgrade_to!('starter')
        
        expect(result).to be false
        expect(subscription.plan_name).to eq('professional')
      end
    end
    
    describe '#cancel!' do
      it 'cancels subscription and sets cancelled_at' do
        subscription = create(:subscription, status: :active)
        time_before = Time.current
        
        subscription.cancel!
        
        expect(subscription.status).to eq('cancelled')
        expect(subscription.cancelled_at).to be >= time_before
      end
    end
    
    describe '#reactivate!' do
      it 'reactivates cancelled subscription' do
        subscription = create(:subscription, 
          status: :cancelled,
          cancelled_at: 1.day.ago
        )
        
        result = subscription.reactivate!
        
        expect(result).to be true
        expect(subscription.status).to eq('active')
        expect(subscription.cancelled_at).to be_nil
        expect(subscription.billing_cycle_started_at).to be_present
      end
      
      it 'returns false for non-cancelled subscriptions' do
        subscription = create(:subscription, status: :active)
        result = subscription.reactivate!
        
        expect(result).to be false
      end
    end
  end
  
  describe 'private methods' do
    describe '#generate_plan_features' do
      it 'generates correct features for starter plan' do
        subscription = create(:subscription, plan_name: 'starter')
        features = subscription.plan_features
        
        expect(features['real_time_monitoring']).to be true
        expect(features['performance_alerts']).to be true
        expect(features['basic_recommendations']).to be true
        expect(features['advanced_recommendations']).to be_falsey
      end
      
      it 'generates correct features for professional plan' do
        subscription = create(:subscription, plan_name: 'professional')
        features = subscription.plan_features
        
        expect(features['advanced_recommendations']).to be true
        expect(features['api_access']).to be true
        expect(features['white_label']).to be false
      end
      
      it 'generates correct features for enterprise plan' do
        subscription = create(:subscription, plan_name: 'enterprise')
        features = subscription.plan_features
        
        expect(features['white_label']).to be true
        expect(features['dedicated_support']).to be true
        expect(features['custom_integrations']).to be true
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:account_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:plan_name).of_type(:string).with_options(null: false) }
    it { should have_db_column(:status).of_type(:integer).with_options(null: false, default: 'trial') }
    it { should have_db_column(:monthly_price).of_type(:decimal) }
    it { should have_db_column(:usage_limits).of_type(:jsonb) }
    it { should have_db_column(:current_usage).of_type(:jsonb) }
    it { should have_db_column(:plan_features).of_type(:jsonb) }
    it { should have_db_column(:trial_ends_at).of_type(:datetime) }
    it { should have_db_column(:billing_cycle_started_at).of_type(:datetime) }
    it { should have_db_column(:cancelled_at).of_type(:datetime) }
    it { should have_db_column(:external_subscription_id).of_type(:string) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:account_id) }
    it { should have_db_index(:plan_name) }
    it { should have_db_index(:status) }
    it { should have_db_index(:trial_ends_at) }
    it { should have_db_index(:external_subscription_id).unique }
  end
end