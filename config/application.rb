require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module QuickFixPro
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Rails 8 Solid Queue configuration
    config.active_job.queue_adapter = :solid_queue

    # Time zone configuration
    config.time_zone = "UTC"

    # Multi-tenant configuration
    # TODO: Add rack-cors gem to Gemfile if API CORS support is needed
    # config.middleware.use Rack::Cors do
    #   allow do
    #     origins Rails.application.credentials.dig(:app, :allowed_origins) || ['localhost:3000']
    #     resource '*',
    #       headers: :any,
    #       methods: [:get, :post, :put, :patch, :delete, :options, :head],
    #       credentials: false
    #   end
    # end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
  end
end
