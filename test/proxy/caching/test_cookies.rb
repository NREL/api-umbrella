require_relative "../../test_helper"

class Test::Proxy::Caching::TestCookies < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_caches_requests_with_analytics_cookie
    assert_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "__utma=foo",
    })
  end

  def test_does_not_cache_requests_with_unknown_cookie
    refute_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "foo=bar",
    })
  end

  def test_does_not_cache_requests_with_unknown_and_analytics_cookie
    refute_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "foo=bar; __utma=foo;",
    })
  end

  def test_does_not_cache_responses_that_set_cookies
    refute_cacheable("/api/cacheable-set-cookie/")
  end
end
