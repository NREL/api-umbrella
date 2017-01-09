# Since we're performing all our tests as full-stack integration tests, use the
# production settings as the defaults, so the tests are what we'll see in
# production.
require_relative "./production.rb"

Rails.application.configure do
  config.log_level = :debug

  # Deliver real e-mail if running integration tests with local MailHog as our
  # test SMTP server.
  if(!config.action_mailer.smtp_settings || config.action_mailer.smtp_settings[:address] != "127.0.0.1" || config.action_mailer.smtp_settings[:port] != ApiUmbrellaConfig[:mailhog][:smtp_port])
    config.action_mailer.delivery_method = :test
  end

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr
end

if(Rails.env.test?)
  # For the test environment setup a middleware that looks for the
  # "test_delay_server_responses" cookie on requests, and if it's set, sleeps
  # for that amount of time before returning responses.
  #
  # This can be used for some Capybara integration tests that otherwise might
  # happen too quickly (for example, checking that a loading spinner pops up
  # while making an ajax request).
  class TestDelayServerResponses
    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      if(request.cookies["test_delay_server_responses"].present?)
        sleep(request.cookies["test_delay_server_responses"].to_f)
      end

      @app.call(env)
    end
  end
  Rails.application.config.middleware.use(TestDelayServerResponses)
end
