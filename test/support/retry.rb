# While not ideal, retry certain flaky tests in CI.
if ENV["CI"] == "true"
  require "minitest/retry"
  Minitest::Retry.use!(
    methods_to_retry: [
      "Test::AdminUi::TestApis#test_form",
    ],

    exceptions_to_retry: [
      Selenium::WebDriver::Error::UnknownError,
    ],
  )
end
