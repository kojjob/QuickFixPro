class BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :set_subscription

  def index
    @current_plan = @subscription&.plan_name || "none"
    @payments = @subscription ? @subscription.payments.recent.limit(5) : []
    @next_billing_date = calculate_next_billing_date
    @usage_stats = calculate_usage_stats
  end

  def subscription
    @plans = available_plans
    @current_plan_details = current_plan_details
  end

  def payment_history
    @payments = if @subscription
                  @subscription.payments.recent.page(params[:page]).per(10)
    else
                  Payment.none.page(params[:page])
    end
  end

  def upgrade
    @target_plan = params[:plan]
    @current_plan = @subscription&.plan_name || "none"

    unless valid_upgrade?(@target_plan)
      redirect_to billing_subscription_path, alert: "Invalid upgrade selection"
      return
    end

    @plan_details = plan_details(@target_plan)
  end

  def process_upgrade
    target_plan = params[:plan]
    payment_method = params[:payment_method]

    unless valid_upgrade?(target_plan)
      redirect_to billing_subscription_path, alert: "Invalid upgrade selection"
      return
    end

    # Create or update subscription
    if @subscription
      result = upgrade_subscription(target_plan, payment_method)
    else
      result = create_subscription(target_plan, payment_method)
    end

    if result[:success]
      redirect_to billing_path, notice: "Successfully upgraded to #{target_plan.capitalize} plan!"
    else
      redirect_to billing_subscription_path, alert: result[:message]
    end
  end

  def cancel_subscription
    if @subscription && @subscription.subscription_active?
      @subscription.cancel!
      redirect_to billing_path, notice: "Your subscription has been cancelled. You will have access until the end of your billing period."
    else
      redirect_to billing_path, alert: "No active subscription to cancel"
    end
  end

  private

  def set_account
    @account = current_user.account
    redirect_to root_path, alert: "Account not found" unless @account
  end

  def set_subscription
    @subscription = @account.current_subscription
  end

  def calculate_next_billing_date
    return nil unless @subscription && @subscription.subscription_active?

    if @subscription.billing_cycle_started_at
      @subscription.billing_cycle_started_at + 1.month
    else
      @subscription.created_at + 1.month
    end
  end

  def calculate_usage_stats
    return default_usage_stats unless @subscription

    {
      websites: {
        used: @account.websites.count,
        limit: @subscription.usage_limit_for(:websites),
        percentage: @subscription.usage_percentage_for(:websites)
      },
      monthly_audits: {
        used: @subscription.current_usage_for(:monthly_audits),
        limit: @subscription.usage_limit_for(:monthly_audits),
        percentage: @subscription.usage_percentage_for(:monthly_audits)
      },
      users: {
        used: @account.users.count,
        limit: @subscription.usage_limit_for(:users),
        percentage: @subscription.usage_percentage_for(:users)
      }
    }
  end

  def default_usage_stats
    {
      websites: { used: 0, limit: 0, percentage: 0 },
      monthly_audits: { used: 0, limit: 0, percentage: 0 },
      users: { used: 0, limit: 0, percentage: 0 }
    }
  end

  def available_plans
    [
      {
        name: "starter",
        display_name: "Starter",
        price: 29.00,
        features: Subscription::PLAN_LIMITS["starter"]
      },
      {
        name: "professional",
        display_name: "Professional",
        price: 99.00,
        features: Subscription::PLAN_LIMITS["professional"],
        popular: true
      },
      {
        name: "enterprise",
        display_name: "Enterprise",
        price: 299.00,
        features: Subscription::PLAN_LIMITS["enterprise"]
      }
    ]
  end

  def current_plan_details
    return nil unless @subscription

    {
      name: @subscription.plan_name,
      display_name: @subscription.plan_name.capitalize,
      price: @subscription.monthly_price,
      features: @subscription.plan_limits,
      status: @subscription.status
    }
  end

  def plan_details(plan_name)
    available_plans.find { |p| p[:name] == plan_name }
  end

  def valid_upgrade?(target_plan)
    return false unless %w[starter professional enterprise].include?(target_plan)
    return true unless @subscription

    @subscription.can_upgrade_to?(target_plan)
  end

  def upgrade_subscription(target_plan, payment_method)
    @subscription.upgrade_to!(target_plan)

    # Process payment for the upgrade
    payment_service = PaymentService.new(@subscription)
    payment_service.process_subscription_renewal(current_user.email, payment_method)
  rescue => e
    { success: false, message: e.message }
  end

  def create_subscription(target_plan, payment_method)
    @subscription = @account.subscriptions.create!(
      plan_name: target_plan,
      status: :active,
      monthly_price: Subscription::PLAN_PRICES[target_plan]
    )

    # Process initial payment
    payment_service = PaymentService.new(@subscription)
    payment_service.process_subscription_renewal(current_user.email, payment_method)
  rescue => e
    { success: false, message: e.message }
  end
end
