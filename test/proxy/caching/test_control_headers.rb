require_relative "../../test_helper"

class Test::Proxy::Caching::TestControlHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_does_not_cache_unless_explicit
    refute_cacheable("/api/cacheable-but-not/")
  end

  def test_caches_based_on_cache_control_max_age
    assert_cacheable("/api/cacheable-cache-control-max-age/")
  end

  def test_caches_based_on_cache_control_s_maxage
    assert_cacheable("/api/cacheable-cache-control-s-maxage/")
  end

  def test_caches_based_on_cache_control_case_insensitive
    assert_cacheable("/api/cacheable-cache-control-case-insensitive/")
  end

  def test_caches_based_on_expires
    assert_cacheable("/api/cacheable-expires/")
  end

  def test_does_not_cache_expires_0
    first = Typhoeus::Request.new("http://127.0.0.1:9080/api/cacheable-expires-0/?unique_test_id=#{unique_test_id}", http_options).run
    assert_equal(200, first.code, first.body)
    assert_equal("0", first.headers["expires"])

    # TrafficServer has a bug where Expires: 0 and Expires: Past Date headers
    # might be cached for around a second. Probably not a huge deal, but this
    # would be nice if they fixed it. In the meantime, we'll sleep 1 second
    # between the requests. See: https://issues.apache.org/jira/browse/TS-2961
    sleep 1.5

    second = Typhoeus::Request.new("http://127.0.0.1:9080/api/cacheable-expires-0/?unique_test_id=#{unique_test_id}", http_options).run
    assert_equal(200, second.code, second.body)
    assert_equal("0", second.headers["expires"])

    assert_equal("MISS", first.headers["x-cache"])
    assert_equal("MISS", second.headers["x-cache"])
    refute_equal(first.headers["x-unique-output"], second.headers["x-unique-output"])
  end

  def test_does_not_cache_expires_past
    first = Typhoeus::Request.new("http://127.0.0.1:9080/api/cacheable-expires-past/?unique_test_id=#{unique_test_id}", http_options).run
    assert_equal(200, first.code, first.body)
    assert_equal("Sat, 05 Sep 2015 17:58:16 GMT", first.headers["expires"])

    # TrafficServer has a bug where Expires: 0 and Expires: Past Date headers
    # might be cached for around a second. Probably not a huge deal, but this
    # would be nice if they fixed it. In the meantime, we'll sleep 1 second
    # between the requests. See: https://issues.apache.org/jira/browse/TS-2961
    sleep 1.5

    second = Typhoeus::Request.new("http://127.0.0.1:9080/api/cacheable-expires-past/?unique_test_id=#{unique_test_id}", http_options).run
    assert_equal(200, second.code, second.body)
    assert_equal("Sat, 05 Sep 2015 17:58:16 GMT", second.headers["expires"])

    assert_equal("MISS", first.headers["x-cache"])
    assert_equal("MISS", second.headers["x-cache"])
    refute_equal(first.headers["x-unique-output"], second.headers["x-unique-output"])
  end

  def test_caches_based_on_surrogate_control_max_age
    assert_cacheable("/api/cacheable-surrogate-control-max-age/")
  end

  def test_caches_based_on_surrogate_control_case_insensitive
    assert_cacheable("/api/cacheable-surrogate-control-case-insensitive/")
  end

  def test_surrogate_control_has_precedence_over_cache_control
    assert_cacheable("/api/cacheable-surrogate-control-and-cache-control/")
  end

  def test_removes_surrogate_control_header_from_client
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-surrogate-control-max-age/", http_options)
    assert_response_code(200, response)
    refute(response.headers["surrogate-control"])
  end

  def test_leaves_cache_control_header_when_surrogate_control_present
    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-surrogate-control-and-cache-control/", http_options)
    assert_response_code(200, response)
    refute(response.headers["surrogate-control"])
    assert_equal("max-age=0, private, must-revalidate", response.headers["cache-control"])
  end

  def test_ignores_request_no_cache_header
    assert_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cache-Control" => "no-cache",
    })
  end
end
