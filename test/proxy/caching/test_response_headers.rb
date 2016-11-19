require_relative "../../test_helper"

class TestProxyCachingResponseHeaders < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_x_cache
    url = "http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("HIT", response.headers["x-cache"])

    # TrafficServer has two different categories for cache hits internally,
    # in-memory RAM hits and disk hits. So make sure we account for both my
    # making 3 requests.
    response = Typhoeus.get(url, self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_x_cache_hit_from_backend
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_x_cache_custom_miss_from_backend
    url = "http://127.0.0.1:9080/api/cacheable-backend-reports-not-cached/?unique_test_id=#{unique_test_id}"
    response = Typhoeus.get(url, self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("BACKEND-MISS", response.headers["x-cache"])

    response = Typhoeus.get(url, self.http_options)
    assert_equal(200, response.code, response.body)
    assert_equal("HIT", response.headers["x-cache"])
  end

  def test_age_increases
    3.times do |index|
      sleep(1.1) unless(index == 0)

      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-cache-control-max-age/?unique_test_id=#{unique_test_id}", self.http_options)
      assert_equal(200, response.code, response.body)
      assert_operator(response.headers["age"].to_i, :>=, index + 0)
      assert_operator(response.headers["age"].to_i, :<=, index + 1)
    end
  end

  def test_age_increases_from_backend_age
    3.times do |index|
      sleep(1.1) unless(index == 0)

      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-backend-reports-cached/?unique_test_id=#{unique_test_id}", self.http_options)
      assert_equal(200, response.code, response.body)
      assert_operator(response.headers["age"].to_i, :>=, index + 3)
      assert_operator(response.headers["age"].to_i, :<=, index + 4)
    end
  end
end
