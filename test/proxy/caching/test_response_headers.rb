require_relative "../../test_helper"

class Test::Proxy::Caching::TestResponseHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_x_cache
    url = "http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, http_options)
    assert_response_code(200, response)
    assert_equal("MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, http_options)
    assert_response_code(200, response)
    assert_equal("HIT", response.headers["x-cache"])

    # TrafficServer has two different categories for cache hits internally,
    # in-memory RAM hits and disk hits. So make sure we account for both my
    # making 3 requests.
    response = Typhoeus.get(url, http_options)
    assert_response_code(200, response)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_x_cache_hit_from_backend
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_x_cache_custom_miss_from_backend
    url = "http://127.0.0.1:9080/api/cacheable-backend-reports-not-cached/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, http_options)
    assert_response_code(200, response)
    assert_equal("BACKEND-MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, http_options)
    assert_response_code(200, response)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_x_cache_redirect_temporary
    url = "http://127.0.0.1:9080/api/redirect/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, http_options)
    assert_response_code(302, response)
    assert_equal("MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, http_options)
    assert_response_code(302, response)
    assert_equal("MISS", response.headers["x-cache"])
  end

  def test_x_cache_redirect_permanent
    url = "http://127.0.0.1:9080/api/redirect-301/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, http_options)
    assert_response_code(301, response)
    assert_equal("MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, http_options)
    assert_response_code(301, response)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_age_increases
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    first_age = response.headers["age"].to_i
    assert_operator(first_age, :>=, 0)

    sleep 1.1
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    second_age = response.headers["age"].to_i
    assert_operator(second_age, :>, first_age)

    sleep 1.1
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    third_age = response.headers["age"].to_i
    assert_operator(third_age, :>, second_age)
  end

  def test_age_increases_from_backend_age
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    first_age = response.headers["age"].to_i
    assert_operator(first_age, :>=, 3)

    sleep 1.1
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    second_age = response.headers["age"].to_i
    assert_operator(second_age, :>, first_age)

    sleep 1.1
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", http_options)
    assert_response_code(200, response)
    third_age = response.headers["age"].to_i
    assert_operator(third_age, :>, second_age)
  end
end
