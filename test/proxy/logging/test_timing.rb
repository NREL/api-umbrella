require_relative "../../test_helper"

# Perform some logging tests that are more sensitive to timing and system load,
# so we don't parallelize these with other tests.
class Test::Proxy::Logging::TestTiming < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging

  def setup
    super
    setup_server
  end

  def test_request_at_is_time_request_finishes_not_starts
    request_start = Time.now.utc
    response = Typhoeus.get("http://127.0.0.1:9080/api/delay/3000", log_http_options)
    request_end = Time.now.utc
    assert_response_code(200, response)

    record = wait_for_log(response)[:hit_source]

    logged_response_time = record["response_time"]
    assert_operator(logged_response_time, :>=, 2500)

    local_response_time = request_end - request_start
    assert_operator(local_response_time, :>=, 2.5)

    assert_in_delta(request_end.strftime("%s%L").to_i, record.fetch("@timestamp"), 500)
  end
end
