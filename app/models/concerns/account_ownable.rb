module AccountOwnable
  extend ActiveSupport::Concern

  included do
    belongs_to :account

    scope :for_account, ->(account) { where(account: account) }
    scope :for_current_account, -> { where(account: Current.account) }

    validates :account, presence: true

    before_validation :set_account_from_current, if: -> { account.blank? && Current.account }
  end

  private

  def set_account_from_current
    self.account = Current.account
  end
end
