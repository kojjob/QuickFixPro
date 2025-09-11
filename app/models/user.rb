class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :trackable

  # Associations
  belongs_to :account
  has_many :created_accounts, class_name: 'Account', foreign_key: 'created_by_id', dependent: :nullify
  has_many :websites, foreign_key: 'created_by_id', dependent: :nullify
  has_many :triggered_audits, class_name: 'AuditReport', foreign_key: 'triggered_by_id', dependent: :nullify

  # Callbacks
  before_validation :normalize_names

  # Validations
  validates :first_name, :last_name, presence: true
  validates :email, uniqueness: { scope: :account_id }
  validates :role, presence: true

  # Enums
  enum :role, { owner: 0, admin: 1, member: 2, viewer: 3 }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_role, ->(role) { where(role: role) }

  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def can_manage_account?
    owner? || admin?
  end

  def can_create_websites?
    !viewer?
  end

  def can_trigger_audits?
    !viewer?
  end

  def can_view_billing?
    owner? || admin?
  end

  def account_owner?
    owner?
  end

  private

  def normalize_names
    self.first_name = first_name&.strip&.titleize
    self.last_name = last_name&.strip&.titleize
  end
end
