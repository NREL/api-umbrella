# While not ideal, retry certain flaky tests in CI.
if ENV["CI"] == "true"
  require "minitest/retry"
  Minitest::Retry.use!(
    methods_to_retry: [
      "Test::AdminUi::TestApis#test_form",
      "Test::Proxy::TestTimeoutsResponse#test_response_closes_when_chunk_delay_exceeds_read_timeout",
    ],

    exceptions_to_retry: [
      Selenium::WebDriver::Error::UnknownError,
    ],
  )
end
