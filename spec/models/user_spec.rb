require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should belong_to(:account) }
    it { should have_many(:created_accounts).class_name('Account').with_foreign_key('created_by_id').dependent(:nullify) }
    it { should have_many(:websites).with_foreign_key('created_by_id').dependent(:nullify) }
    it { should have_many(:triggered_audits).class_name('AuditReport').with_foreign_key('triggered_by_id').dependent(:nullify) }
  end

  describe 'validations' do
    subject { build(:user) }
    
    it { should validate_presence_of(:first_name) }
    it { should validate_presence_of(:last_name) }
    it { should validate_presence_of(:email) }
    it { should validate_presence_of(:role) }
    
    describe 'email uniqueness' do
      let(:account) { create(:account) }
      let!(:existing_user) { create(:user, email: 'test@example.com', account: account) }
      
      it 'validates uniqueness within the same account' do
        new_user = build(:user, email: 'test@example.com', account: account)
        expect(new_user).not_to be_valid
        expect(new_user.errors[:email]).to include('has already been taken')
      end
      
      it 'does not allow same email in different accounts due to unique index' do
        other_account = create(:account)
        new_user = build(:user, email: 'test@example.com', account: other_account)
        expect(new_user).not_to be_valid
        expect(new_user.errors[:email]).to include('has already been taken')
      end
    end
    
    # Devise validations
    it { should validate_length_of(:password).is_at_least(6) }
    it { should validate_confirmation_of(:password) }
    
    describe 'email format' do
      it 'accepts valid email addresses' do
        valid_emails = ['user@example.com', 'user+tag@example.co.uk', 'user.name@example.org']
        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid
        end
      end
      
      it 'rejects invalid email addresses' do
        # Note: Devise accepts some formats that might seem invalid like 'user@example'
        # These are the formats that Devise actually rejects
        invalid_emails = ['user', 'user@', '@example.com', 'user @example.com']
        invalid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).not_to be_valid
        end
      end
    end
  end

  describe 'enums' do
    it { should define_enum_for(:role).with_values(owner: 0, admin: 1, member: 2, viewer: 3) }
  end

  describe 'callbacks' do
    describe '#normalize_names' do
      it 'titleizes and strips first name' do
        user = build(:user, first_name: '  john  ')
        user.valid?
        expect(user.first_name).to eq('John')
      end
      
      it 'titleizes and strips last name' do
        user = build(:user, last_name: '  doe  ')
        user.valid?
        expect(user.last_name).to eq('Doe')
      end
      
      it 'handles multi-word names correctly' do
        user = build(:user, first_name: 'mary ann', last_name: 'van der berg')
        user.valid?
        expect(user.first_name).to eq('Mary Ann')
        expect(user.last_name).to eq('Van Der Berg')
      end
      
      it 'handles nil names gracefully' do
        user = build(:user, first_name: nil, last_name: nil)
        expect { user.valid? }.not_to raise_error
      end
    end
  end

  describe 'scopes' do
    describe '.active' do
      let!(:active_user) { create(:user, active: true) }
      let!(:inactive_user) { create(:user, :inactive) }
      
      it 'returns only active users' do
        expect(User.active).to contain_exactly(active_user)
      end
    end
    
    describe '.by_role' do
      let(:account) { create(:account) }
      let!(:owner) { create(:user, :owner, account: account) }
      let!(:admin) { create(:user, :admin, account: account) }
      let!(:member) { create(:user, :member, account: account) }
      let!(:viewer) { create(:user, :viewer, account: account) }
      
      it 'returns users with specified role' do
        expect(User.by_role('owner')).to contain_exactly(owner)
        expect(User.by_role('admin')).to contain_exactly(admin)
        expect(User.by_role('member')).to contain_exactly(member)
        expect(User.by_role('viewer')).to contain_exactly(viewer)
      end
    end
  end

  describe 'instance methods' do
    let(:user) { build(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
    
    describe '#full_name' do
      it 'returns the full name' do
        expect(user.full_name).to eq('John Doe')
      end
      
      it 'handles empty first name' do
        user.first_name = ''
        expect(user.full_name).to eq('Doe')
      end
      
      it 'handles empty last name' do
        user.last_name = ''
        expect(user.full_name).to eq('John')
      end
      
      it 'handles both names empty' do
        user.first_name = ''
        user.last_name = ''
        expect(user.full_name).to eq('')
      end
    end
    
    describe '#display_name' do
      it 'returns full name when present' do
        expect(user.display_name).to eq('John Doe')
      end
      
      it 'returns email when full name is blank' do
        user.first_name = ''
        user.last_name = ''
        expect(user.display_name).to eq('john@example.com')
      end
    end
    
    describe 'permission methods' do
      describe '#can_manage_account?' do
        it 'returns true for owners' do
          user.role = :owner
          expect(user.can_manage_account?).to be true
        end
        
        it 'returns true for admins' do
          user.role = :admin
          expect(user.can_manage_account?).to be true
        end
        
        it 'returns false for members' do
          user.role = :member
          expect(user.can_manage_account?).to be false
        end
        
        it 'returns false for viewers' do
          user.role = :viewer
          expect(user.can_manage_account?).to be false
        end
      end
      
      describe '#can_create_websites?' do
        it 'returns true for owners' do
          user.role = :owner
          expect(user.can_create_websites?).to be true
        end
        
        it 'returns true for admins' do
          user.role = :admin
          expect(user.can_create_websites?).to be true
        end
        
        it 'returns true for members' do
          user.role = :member
          expect(user.can_create_websites?).to be true
        end
        
        it 'returns false for viewers' do
          user.role = :viewer
          expect(user.can_create_websites?).to be false
        end
      end
      
      describe '#can_trigger_audits?' do
        it 'returns true for owners' do
          user.role = :owner
          expect(user.can_trigger_audits?).to be true
        end
        
        it 'returns true for admins' do
          user.role = :admin
          expect(user.can_trigger_audits?).to be true
        end
        
        it 'returns true for members' do
          user.role = :member
          expect(user.can_trigger_audits?).to be true
        end
        
        it 'returns false for viewers' do
          user.role = :viewer
          expect(user.can_trigger_audits?).to be false
        end
      end
      
      describe '#can_view_billing?' do
        it 'returns true for owners' do
          user.role = :owner
          expect(user.can_view_billing?).to be true
        end
        
        it 'returns true for admins' do
          user.role = :admin
          expect(user.can_view_billing?).to be true
        end
        
        it 'returns false for members' do
          user.role = :member
          expect(user.can_view_billing?).to be false
        end
        
        it 'returns false for viewers' do
          user.role = :viewer
          expect(user.can_view_billing?).to be false
        end
      end
      
      describe '#account_owner?' do
        it 'returns true for owners' do
          user.role = :owner
          expect(user.account_owner?).to be true
        end
        
        it 'returns false for non-owners' do
          user.role = :admin
          expect(user.account_owner?).to be false
          
          user.role = :member
          expect(user.account_owner?).to be false
          
          user.role = :viewer
          expect(user.account_owner?).to be false
        end
      end
    end
  end

  describe 'Devise modules' do
    it 'includes database_authenticatable module' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end
    
    it 'includes registerable module' do
      expect(User.devise_modules).to include(:registerable)
    end
    
    it 'includes recoverable module' do
      expect(User.devise_modules).to include(:recoverable)
    end
    
    it 'includes rememberable module' do
      expect(User.devise_modules).to include(:rememberable)
    end
    
    it 'includes validatable module' do
      expect(User.devise_modules).to include(:validatable)
    end
    
    it 'includes trackable module' do
      expect(User.devise_modules).to include(:trackable)
    end
  end

  describe 'database columns' do
    it { should have_db_column(:id).of_type(:uuid) }
    it { should have_db_column(:email).of_type(:string).with_options(null: false, default: '') }
    it { should have_db_column(:encrypted_password).of_type(:string).with_options(null: false, default: '') }
    it { should have_db_column(:reset_password_token).of_type(:string) }
    it { should have_db_column(:reset_password_sent_at).of_type(:datetime) }
    it { should have_db_column(:remember_created_at).of_type(:datetime) }
    it { should have_db_column(:sign_in_count).of_type(:integer).with_options(default: 0) }
    it { should have_db_column(:current_sign_in_at).of_type(:datetime) }
    it { should have_db_column(:last_sign_in_at).of_type(:datetime) }
    it { should have_db_column(:current_sign_in_ip).of_type(:string) }
    it { should have_db_column(:last_sign_in_ip).of_type(:string) }
    it { should have_db_column(:account_id).of_type(:uuid).with_options(null: false) }
    it { should have_db_column(:first_name).of_type(:string) }
    it { should have_db_column(:last_name).of_type(:string) }
    it { should have_db_column(:role).of_type(:integer).with_options(default: 'owner', null: false) }
    it { should have_db_column(:active).of_type(:boolean).with_options(default: true) }
    it { should have_db_column(:preferences).of_type(:jsonb).with_options(default: {}) }
    it { should have_db_column(:created_at).of_type(:datetime) }
    it { should have_db_column(:updated_at).of_type(:datetime) }
  end

  describe 'indexes' do
    it { should have_db_index([:account_id, :email]).unique }
    it { should have_db_index([:account_id, :role]) }
    it { should have_db_index(:account_id) }
    it { should have_db_index(:active) }
    it { should have_db_index(:email).unique }
    it { should have_db_index(:preferences) }
    it { should have_db_index(:reset_password_token).unique }
  end
end
