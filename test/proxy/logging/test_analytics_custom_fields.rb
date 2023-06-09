require_relative "../../test_helper"

class Test::Proxy::Logging::TestAnalyticsCustomFields < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Logging
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_custom_field1
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom1" => unique_test_id,
        },
      }),
    }))
    assert_response_code(200, response)
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom1"])

    record = wait_for_log(response)[:hit_source]
    assert_equal(unique_test_id, record.fetch("response_custom1"))
    assert_nil(record["response_custom2"])
    assert_nil(record["response_custom3"])
  end

  def test_custom_field2
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom2" => unique_test_id,
        },
      }),
    }))
    assert_response_code(200, response)
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom2"])

    record = wait_for_log(response)[:hit_source]
    assert_nil(record["response_custom1"])
    assert_equal(unique_test_id, record.fetch("response_custom2"))
    assert_nil(record["response_custom3"])
  end

  def test_custom_field3
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom3" => unique_test_id,
        },
      }),
    }))
    assert_response_code(200, response)
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom3"])

    record = wait_for_log(response)[:hit_source]
    assert_nil(record["response_custom1"])
    assert_nil(record["response_custom2"])
    assert_equal(unique_test_id, record.fetch("response_custom3"))
  end

  def test_all_custom_fields
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom1" => "hello",
          "X-Api-Umbrella-Analytics-Custom2" => "world",
          "X-Api-Umbrella-Analytics-Custom3" => "!",
        },
      }),
    }))
    assert_response_code(200, response)
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom1"])
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom2"])
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom3"])

    record = wait_for_log(response)[:hit_source]
    assert_equal("hello", record.fetch("response_custom1"))
    assert_equal("world", record.fetch("response_custom2"))
    assert_equal("!", record.fetch("response_custom3"))
  end

  def test_truncates_values_to_400_chars
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom1" => "A" * 500,
          "X-Api-Umbrella-Analytics-Custom2" => "B" * 500,
          "X-Api-Umbrella-Analytics-Custom3" => "C" * 500,
        },
      }),
    }))
    assert_response_code(200, response)
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom1"])
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom2"])
    assert_nil(response.headers["X-Api-Umbrella-Analytics-Custom3"])

    record = wait_for_log(response)[:hit_source]
    assert_equal("A" * 400, record.fetch("response_custom1"))
    assert_equal("B" * 400, record.fetch("response_custom2"))
    assert_equal("C" * 400, record.fetch("response_custom3"))
  end

  def test_does_nothing_with_unknown_custom_fields
    response = Typhoeus.get("http://127.0.0.1:9080/api/set-http-response-headers/", log_http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "http_response_headers" => {
          "X-Api-Umbrella-Analytics-Custom0" => "custom0",
          "X-Api-Umbrella-Analytics-Custom4" => "custom4",
        },
      }),
    }))
    assert_response_code(200, response)
    assert_equal("custom0", response.headers["X-Api-Umbrella-Analytics-Custom0"])
    assert_equal("custom4", response.headers["X-Api-Umbrella-Analytics-Custom4"])

    record = wait_for_log(response)[:hit_source]
    refute_match("custom0", MultiJson.dump(record))
    refute_match("custom4", MultiJson.dump(record))
  end
end
