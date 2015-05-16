ApiUmbrella::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # The test environment is used exclusively to run your application's
  # test suite. You never need to work with it otherwise. Remember that
  # your test database is "scratch space" for the test suite and is wiped
  # and recreated between test runs. Don't rely on the data there!
  config.cache_classes = true

  # Configure static asset server for tests with Cache-Control for performance
  config.serve_static_assets = true
  config.static_cache_control = "public, max-age=3600"

  # Log error messages when you accidentally call methods on nil
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local       = true
  config.action_controller.perform_caching = false

  # Raise exceptions instead of rendering exception templates
  config.action_dispatch.show_exceptions = true

  # Disable request forgery protection in test environment
  config.action_controller.allow_forgery_protection    = false

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Print deprecation notices to the stderr
  config.active_support.deprecation = :stderr

  if(ENV["PRECOMPILE_TEST_ASSETS"].to_s != "false")
    # Use precompiled assets in test mode so we can properly catch errors
    # triggered by not having assets in the precompile list.
    config.assets.compile = false
    config.assets.digest = true
    config.assets.prefix = "/test-assets"

    # Precompile additional assets for the test environment.
    config.assets.precompile += %w(
      admin_test.css
      admin_test.js
    )

    config.before_initialize do |app|
      # Run the asset precompile phase prior to running tests so that we can test
      # with precompiled assets (so we're more properly testing for any potential
      # missing precompiled assets). However, note that we have to call this
      # here, instead of in something like an rspec before suite so that the
      # precompile happens early enough so that the current environment can load
      # the precompiled digests.
      unless ENV["PRECOMPILE_TEST_ASSETS"]
        system("RAILS_ENV=test PRECOMPILE_TEST_ASSETS=true bundle exec rake assets:precompile")
      end
    end
  end
end
