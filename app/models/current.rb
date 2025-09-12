class Current < ActiveSupport::CurrentAttributes
  attribute :user, :account

  def user=(user)
    super
    self.account = user&.account
  end

  def account_or_raise!
    account || raise(StandardError, "No current account set")
  end

  def user_or_raise!
    user || raise(StandardError, "No current user set")
  end
end
