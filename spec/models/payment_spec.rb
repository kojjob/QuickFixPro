require 'rails_helper'

RSpec.describe Payment, type: :model do
  let(:subscription) { create(:subscription) }
  let(:payment) { create(:payment, subscription: subscription) }
  
  describe 'associations' do
    it { should belong_to(:subscription) }
  end
  
  describe 'validations' do
    describe 'amount' do
      it { should validate_presence_of(:amount) }
      it { should validate_numericality_of(:amount).is_greater_than(0) }
      
      it 'rejects zero amounts' do
        payment = build(:payment, amount: 0)
        expect(payment).not_to be_valid
        expect(payment.errors[:amount]).to be_present
      end
      
      it 'rejects negative amounts' do
        payment = build(:payment, amount: -10.00)
        expect(payment).not_to be_valid
        expect(payment.errors[:amount]).to be_present
      end
    end
    
    describe 'status' do
      it { should validate_presence_of(:status) }
      
      it 'accepts valid statuses' do
        %w[pending processing succeeded failed refunded cancelled].each do |status|
          payment = build(:payment, status: status)
          expect(payment).to be_valid
        end
      end
      
      it 'rejects invalid statuses' do
        payment = build(:payment, status: 'invalid_status')
        expect(payment).not_to be_valid
        expect(payment.errors[:status]).to be_present
      end
    end
    
    describe 'payment_method' do
      it { should validate_presence_of(:payment_method) }
      
      it 'accepts valid payment methods' do
        %w[credit_card debit_card bank_transfer paypal].each do |method|
          payment = build(:payment, payment_method: method)
          expect(payment).to be_valid
        end
      end
      
      it 'rejects invalid payment methods' do
        payment = build(:payment, payment_method: 'bitcoin')
        expect(payment).not_to be_valid
        expect(payment.errors[:payment_method]).to be_present
      end
    end
    
    describe 'invoice_number' do
      it 'validates uniqueness' do
        payment1 = create(:payment, invoice_number: 'INV-2024-000001')
        payment2 = build(:payment, invoice_number: 'INV-2024-000001')
        expect(payment2).not_to be_valid
        expect(payment2.errors[:invoice_number]).to be_present
      end
      
      it 'allows nil values' do
        payment = build(:payment, invoice_number: nil)
        expect(payment).to be_valid
      end
    end
    
    describe 'stripe_payment_intent_id' do
      it 'validates uniqueness' do
        payment1 = create(:payment, stripe_payment_intent_id: 'pi_test123')
        payment2 = build(:payment, stripe_payment_intent_id: 'pi_test123')
        expect(payment2).not_to be_valid
        expect(payment2.errors[:stripe_payment_intent_id]).to be_present
      end
      
      it 'allows nil values' do
        payment = build(:payment, stripe_payment_intent_id: nil)
        expect(payment).to be_valid
      end
    end
  end
  
  describe 'constants' do
    describe 'VALID_STATUSES' do
      it 'defines all valid payment statuses' do
        expect(Payment::VALID_STATUSES).to eq(%w[pending processing succeeded failed refunded cancelled])
      end
    end
    
    describe 'VALID_PAYMENT_METHODS' do
      it 'defines all valid payment methods' do
        expect(Payment::VALID_PAYMENT_METHODS).to eq(%w[credit_card debit_card bank_transfer paypal])
      end
    end
    
    describe 'MAX_RETRIES' do
      it 'defines maximum retry attempts' do
        expect(Payment::MAX_RETRIES).to eq(3)
      end
    end
  end
  
  describe 'scopes' do
    describe '.successful' do
      it 'returns payments with succeeded status' do
        succeeded_payment = create(:payment, status: 'succeeded')
        failed_payment = create(:payment, status: 'failed')
        pending_payment = create(:payment, status: 'pending')
        
        expect(Payment.successful).to include(succeeded_payment)
        expect(Payment.successful).not_to include(failed_payment, pending_payment)
      end
    end
    
    describe '.failed' do
      it 'returns payments with failed status' do
        succeeded_payment = create(:payment, status: 'succeeded')
        failed_payment = create(:payment, status: 'failed')
        pending_payment = create(:payment, status: 'pending')
        
        expect(Payment.failed).to include(failed_payment)
        expect(Payment.failed).not_to include(succeeded_payment, pending_payment)
      end
    end
    
    describe '.pending' do
      it 'returns payments with pending status' do
        succeeded_payment = create(:payment, status: 'succeeded')
        failed_payment = create(:payment, status: 'failed')
        pending_payment = create(:payment, status: 'pending')
        
        expect(Payment.pending).to include(pending_payment)
        expect(Payment.pending).not_to include(succeeded_payment, failed_payment)
      end
    end
    
    describe '.current_month' do
      it 'returns payments from the current month' do
        current_month_payment = create(:payment, created_at: Time.current)
        last_month_payment = create(:payment, created_at: 1.month.ago)
        next_month_payment = create(:payment, created_at: 1.month.from_now)
        
        expect(Payment.current_month).to include(current_month_payment)
        expect(Payment.current_month).not_to include(last_month_payment, next_month_payment)
      end
    end
    
    describe '.recent' do
      it 'orders payments by created_at descending' do
        old_payment = create(:payment, created_at: 3.days.ago)
        middle_payment = create(:payment, created_at: 1.day.ago)
        new_payment = create(:payment, created_at: 1.hour.ago)
        
        expect(Payment.recent).to eq([new_payment, middle_payment, old_payment])
      end
    end
    
    describe '.for_subscription' do
      it 'returns payments for a specific subscription' do
        subscription1 = create(:subscription)
        subscription2 = create(:subscription)
        payment1 = create(:payment, subscription: subscription1)
        payment2 = create(:payment, subscription: subscription2)
        
        expect(Payment.for_subscription(subscription1)).to include(payment1)
        expect(Payment.for_subscription(subscription1)).not_to include(payment2)
      end
    end
  end
  
  describe 'callbacks' do
    describe 'before_create' do
      it 'generates invoice number if not present' do
        payment = build(:payment, invoice_number: nil)
        payment.save!
        
        expect(payment.invoice_number).to be_present
        expect(payment.invoice_number).to match(/^INV-\d{4}-\d{6}$/)
      end
      
      it 'does not override existing invoice number' do
        payment = build(:payment, invoice_number: 'CUSTOM-001')
        payment.save!
        
        expect(payment.invoice_number).to eq('CUSTOM-001')
      end
    end
    
    describe 'after_initialize' do
      it 'sets default retry_count to 0' do
        payment = Payment.new
        expect(payment.retry_count).to eq(0)
      end
      
      it 'sets default metadata to empty hash' do
        payment = Payment.new
        expect(payment.metadata).to eq({})
      end
      
      it 'sets default tax_rate to 0.0' do
        payment = Payment.new
        expect(payment.tax_rate).to eq(0.0)
      end
      
      it 'does not override existing values' do
        payment = Payment.new(retry_count: 2, metadata: { key: 'value' }, tax_rate: 0.15)
        expect(payment.retry_count).to eq(2)
        expect(payment.metadata).to eq({ 'key' => 'value' })
        expect(payment.tax_rate).to eq(0.15)
      end
    end
  end
  
  describe 'instance methods' do
    describe '#tax_amount' do
      it 'calculates tax based on amount and tax_rate' do
        payment = build(:payment, amount: 100.00, tax_rate: 0.15)
        expect(payment.tax_amount).to eq(15.00)
      end
      
      it 'rounds to 2 decimal places' do
        payment = build(:payment, amount: 99.99, tax_rate: 0.075)
        expect(payment.tax_amount).to eq(7.50)
      end
      
      it 'returns 0 when tax_rate is nil' do
        payment = build(:payment, amount: 100.00, tax_rate: nil)
        expect(payment.tax_amount).to eq(0.0)
      end
      
      it 'returns 0 when amount is nil' do
        payment = build(:payment, amount: nil, tax_rate: 0.15)
        expect(payment.tax_amount).to eq(0.0)
      end
    end
    
    describe '#total_amount' do
      it 'returns amount plus tax' do
        payment = build(:payment, amount: 100.00, tax_rate: 0.15)
        expect(payment.total_amount).to eq(115.00)
      end
      
      it 'returns amount only when tax_rate is nil' do
        payment = build(:payment, amount: 100.00, tax_rate: nil)
        expect(payment.total_amount).to eq(100.00)
      end
      
      it 'rounds to 2 decimal places' do
        payment = build(:payment, amount: 99.99, tax_rate: 0.075)
        expect(payment.total_amount).to eq(107.49)
      end
    end
    
    describe '#refund!' do
      it 'refunds a successful payment' do
        payment = create(:payment, status: 'succeeded')
        time_before = Time.current
        
        result = payment.refund!
        
        expect(result).to be true
        expect(payment.status).to eq('refunded')
        expect(payment.refunded_at).to be >= time_before
      end
      
      it 'returns false for non-successful payments' do
        payment = create(:payment, status: 'pending')
        result = payment.refund!
        
        expect(result).to be false
        expect(payment.status).to eq('pending')
        expect(payment.refunded_at).to be_nil
      end
      
      it 'returns false if update fails' do
        payment = create(:payment, status: 'succeeded')
        allow(payment).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
        
        result = payment.refund!
        
        expect(result).to be false
      end
    end
    
    describe '#mark_as_failed!' do
      it 'marks payment as failed with timestamp' do
        payment = create(:payment, status: 'pending')
        time_before = Time.current
        
        payment.mark_as_failed!('Insufficient funds')
        
        expect(payment.status).to eq('failed')
        expect(payment.failed_at).to be >= time_before
        expect(payment.failure_reason).to eq('Insufficient funds')
      end
      
      it 'works without failure reason' do
        payment = create(:payment, status: 'pending')
        
        payment.mark_as_failed!
        
        expect(payment.status).to eq('failed')
        expect(payment.failed_at).to be_present
        expect(payment.failure_reason).to be_nil
      end
    end
    
    describe '#increment_retry!' do
      it 'increments the retry count' do
        payment = create(:payment, retry_count: 1)
        
        payment.increment_retry!
        
        expect(payment.retry_count).to eq(2)
      end
    end
    
    describe '#max_retries_reached?' do
      it 'returns true when retry count equals MAX_RETRIES' do
        payment = build(:payment, retry_count: Payment::MAX_RETRIES)
        expect(payment.max_retries_reached?).to be true
      end
      
      it 'returns true when retry count exceeds MAX_RETRIES' do
        payment = build(:payment, retry_count: Payment::MAX_RETRIES + 1)
        expect(payment.max_retries_reached?).to be true
      end
      
      it 'returns false when retry count is less than MAX_RETRIES' do
        payment = build(:payment, retry_count: Payment::MAX_RETRIES - 1)
        expect(payment.max_retries_reached?).to be false
      end
    end
    
    describe '#can_retry?' do
      it 'returns true for failed payments with retries remaining' do
        payment = build(:payment, status: 'failed', retry_count: 1)
        expect(payment.can_retry?).to be true
      end
      
      it 'returns false when max retries reached' do
        payment = build(:payment, status: 'failed', retry_count: Payment::MAX_RETRIES)
        expect(payment.can_retry?).to be false
      end
      
      it 'returns false for non-failed payments' do
        payment = build(:payment, status: 'succeeded', retry_count: 0)
        expect(payment.can_retry?).to be false
      end
    end
    
    describe '#succeeded?' do
      it 'returns true for succeeded status' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.succeeded?).to be true
      end
      
      it 'returns false for other statuses' do
        payment = build(:payment, status: 'pending')
        expect(payment.succeeded?).to be false
      end
    end
    
    describe '#failed?' do
      it 'returns true for failed status' do
        payment = build(:payment, status: 'failed')
        expect(payment.failed?).to be true
      end
      
      it 'returns false for other statuses' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.failed?).to be false
      end
    end
    
    describe '#pending?' do
      it 'returns true for pending status' do
        payment = build(:payment, status: 'pending')
        expect(payment.pending?).to be true
      end
      
      it 'returns false for other statuses' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.pending?).to be false
      end
    end
    
    describe '#processing?' do
      it 'returns true for processing status' do
        payment = build(:payment, status: 'processing')
        expect(payment.processing?).to be true
      end
      
      it 'returns false for other statuses' do
        payment = build(:payment, status: 'pending')
        expect(payment.processing?).to be false
      end
    end
    
    describe '#refunded?' do
      it 'returns true for refunded status' do
        payment = build(:payment, status: 'refunded')
        expect(payment.refunded?).to be true
      end
      
      it 'returns false for other statuses' do
        payment = build(:payment, status: 'succeeded')
        expect(payment.refunded?).to be false
      end
    end
    
    describe '#update_status!' do
      context 'when updating to succeeded' do
        it 'generates invoice number if not present' do
          payment = create(:payment, status: 'pending', invoice_number: nil)
          
          payment.update_status!('succeeded')
          
          expect(payment.status).to eq('succeeded')
          expect(payment.invoice_number).to be_present
        end
        
        it 'keeps existing invoice number' do
          payment = create(:payment, status: 'pending', invoice_number: 'EXISTING-001')
          
          payment.update_status!('succeeded')
          
          expect(payment.status).to eq('succeeded')
          expect(payment.invoice_number).to eq('EXISTING-001')
        end
      end
      
      context 'when updating to failed' do
        it 'sets failed_at timestamp' do
          payment = create(:payment, status: 'pending')
          time_before = Time.current
          
          payment.update_status!('failed')
          
          expect(payment.status).to eq('failed')
          expect(payment.failed_at).to be >= time_before
        end
        
        it 'accepts additional attributes' do
          payment = create(:payment, status: 'pending')
          
          payment.update_status!('failed', failure_reason: 'Card declined')
          
          expect(payment.status).to eq('failed')
          expect(payment.failure_reason).to eq('Card declined')
        end
      end
      
      context 'when updating to refunded' do
        it 'sets refunded_at timestamp' do
          payment = create(:payment, status: 'succeeded')
          time_before = Time.current
          
          payment.update_status!('refunded')
          
          expect(payment.status).to eq('refunded')
          expect(payment.refunded_at).to be >= time_before
        end
      end
      
      it 'merges additional attributes' do
        payment = create(:payment, status: 'pending')
        
        payment.update_status!('processing', metadata: { processor: 'stripe' })
        
        expect(payment.status).to eq('processing')
        expect(payment.metadata).to eq({ 'processor' => 'stripe' })
      end
    end
  end
  
  describe 'private methods' do
    describe '#generate_invoice_number' do
      it 'generates sequential invoice numbers within the same year' do
        payment1 = create(:payment, invoice_number: nil)
        payment2 = create(:payment, invoice_number: nil)
        payment3 = create(:payment, invoice_number: nil)
        
        year = Time.current.year
        expect(payment1.invoice_number).to eq("INV-#{year}-000001")
        expect(payment2.invoice_number).to eq("INV-#{year}-000002")
        expect(payment3.invoice_number).to eq("INV-#{year}-000003")
      end
      
      it 'handles existing invoice numbers correctly' do
        # Create a payment with a specific invoice number
        create(:payment, invoice_number: "INV-#{Time.current.year}-000100")
        
        # Next payment should get the next sequential number
        payment = create(:payment, invoice_number: nil)
        expect(payment.invoice_number).to eq("INV-#{Time.current.year}-000101")
      end
    end
  end
  
  describe 'database columns' do
    it { should have_db_column(:subscription_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:amount).of_type(:decimal) }
    it { should have_db_column(:status).of_type(:string) }
    it { should have_db_column(:payment_method).of_type(:string) }
    it { should have_db_column(:stripe_payment_intent_id).of_type(:string) }
    it { should have_db_column(:stripe_charge_id).of_type(:string) }
    it { should have_db_column(:tax_rate).of_type(:decimal) }
    it { should have_db_column(:refunded_at).of_type(:datetime) }
    it { should have_db_column(:failed_at).of_type(:datetime) }
    it { should have_db_column(:failure_reason).of_type(:text) }
    it { should have_db_column(:invoice_number).of_type(:string) }
    it { should have_db_column(:retry_count).of_type(:integer) }
    it { should have_db_column(:metadata).of_type(:jsonb) }
  end
  
  describe 'database indexes' do
    it { should have_db_index(:subscription_id) }
    it { should have_db_index(:status) }
    it { should have_db_index(:invoice_number).unique }
    it { should have_db_index(:stripe_payment_intent_id).unique }
  end
end