class AccountsController < ApplicationController
  layout "dashboard"
  before_action :authenticate_user!

  def show
    @account = current_account
    @subscription = @account.current_subscription
    @users = @account.users
  end

  def edit
    @account = current_account
  end

  def update
    @account = current_account

    if @account.update(account_params)
      redirect_to account_path, notice: "Account settings updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def account_params
    params.require(:account).permit(:name, :subdomain)
  end
end
