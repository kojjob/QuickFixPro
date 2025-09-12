class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  def create
    build_resource(sign_up_params)

    # Create an account for the new user
    ActiveRecord::Base.transaction do
      # Generate a unique subdomain based on the user's name or email
      subdomain_base = "#{resource.first_name}#{resource.last_name}".downcase.gsub(/[^a-z0-9]/, "")
      subdomain_base = resource.email.split("@").first.downcase.gsub(/[^a-z0-9]/, "") if subdomain_base.length < 3

      # Ensure subdomain is unique
      subdomain = subdomain_base
      counter = 1
      while Account.exists?(subdomain: subdomain)
        subdomain = "#{subdomain_base}#{counter}"
        counter += 1
      end

      # Create the account first
      account = Account.new(
        name: "#{resource.first_name} #{resource.last_name}".strip,
        subdomain: subdomain,
        status: :trial, # Start with trial status
        created_by_id: nil # Will be updated after user is saved
      )

      if account.save
        # Assign the account to the user
        resource.account = account
        resource.role = :owner # First user is the owner

        if resource.save
          # Update the account with the created_by_id
          account.update(created_by_id: resource.id)

          yield resource if block_given?
          if resource.persisted?
            if resource.active_for_authentication?
              set_flash_message! :notice, :signed_up
              sign_up(resource_name, resource)
              respond_with resource, location: after_sign_up_path_for(resource)
            else
              set_flash_message! :notice, :"signed_up_but_#{resource.inactive_message}"
              expire_data_after_sign_in!
              respond_with resource, location: after_inactive_sign_up_path_for(resource)
            end
          else
            clean_up_passwords resource
            set_minimum_password_length
            respond_with resource
          end
        else
          # If user save fails, rollback the account creation
          account.destroy
          clean_up_passwords resource
          set_minimum_password_length
          respond_with resource
        end
      else
        # If account creation fails, add errors to resource
        resource.errors.add(:base, "Could not create account. Please try again.")
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end
  rescue => e
    Rails.logger.error "Registration failed: #{e.message}"
    resource.errors.add(:base, "Registration failed. Please try again.")
    clean_up_passwords resource
    set_minimum_password_length
    respond_with resource
  end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  protected

  # If you have extra params to permit, append them to the sanitizer.
  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
  end

  # If you have extra params to permit, append them to the sanitizer.
  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end

  # The path used after sign up.
  def after_sign_up_path_for(resource)
    dashboard_path
  end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
end
