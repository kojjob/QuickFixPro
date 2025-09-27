module ControllerHelpers
  def sign_in(user)
    # Mock authentication for controller tests
    allow(controller).to receive(:authenticate_user!).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)
    allow(Current).to receive(:user).and_return(user) if defined?(Current)
    allow(Current).to receive(:account).and_return(user.account) if defined?(Current) && user.respond_to?(:account)
  end
end