# Since we're performing all our tests as full-stack integration tests, use the
# production settings as the defaults, so the tests are what we'll see in
# production.
require_relative "./production.rb"

Rails.application.configure do
  config.log_level = :debug

  # Deliver real e-mail if running integration tests with local MailHog as our
  # test SMTP server.
  if(!config.action_mailer.smtp_settings || config.action_mailer.smtp_settings[:address] != "127.0.0.1" || config.action_mailer.smtp_settings[:port] != 13102)
    config.action_mailer.delivery_method = :test
  end

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr
end
