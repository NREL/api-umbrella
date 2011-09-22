Developer::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # In the development environment your application's code is reloaded on
  # every request.  This slows down response time but is perfect for development
  # since you don't have to restart the webserver when you make code changes.
  config.cache_classes = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports
  config.consider_all_requests_local       = true
  config.action_view.debug_rjs             = true

  # Enable caching, so we can properly develop accounting for the cache.
  config.action_controller.perform_caching = true

  # Use a file-based cache store
  config.cache_store = :file_store, "#{Rails.root}/tmp/cache"

  # Don't care if the mailer can't send
  config.action_mailer.raise_delivery_errors = false

  # Print deprecation notices to the Rails logger
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers
  config.action_dispatch.best_standards_support = :builtin
end

