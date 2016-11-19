require_relative "../../test_helper"

class TestProxyCachingHttpMethods < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching
  parallelize_me!

  def setup
    setup_server
  end

  def test_caches_get
    assert_cacheable("/api/cacheable-cache-control-max-age/", :method => "GET")
  end

  def test_does_not_cache_head
    refute_cacheable("/api/cacheable-cache-control-max-age/", :method => "HEAD")
  end

  def test_caches_head_when_get_made_first
    assert_cacheable("/api/cacheable-cache-control-max-age/", :method => "GET")

    response = Typhoeus::Request.new("http://127.0.0.1:9080/api/cacheable-cache-control-max-age/", http_options.deep_merge({
      :method => "HEAD",
      :params => {
        :unique_test_id => unique_test_id,
      },
    })).run
    assert_equal(200, response.code, response.body)
    assert_equal("GET", response.headers["x-received-method"])
    assert_equal("HIT", response.headers["x-cache"])
    assert_equal("", response.body)
  end

  [
    "POST",
    "PUT",
    "PATCH",
    "OPTIONS",
    "DELETE",
  ].each do |http_method|
    define_method("test_does_not_cache_#{http_method.downcase}") do
      refute_cacheable("/api/cacheable-cache-control-max-age/", :method => http_method)
    end

    define_method("test_does_not_cache_#{http_method.downcase}_when_get_made_first") do
      assert_cacheable("/api/cacheable-cache-control-max-age/", :method => "GET")
      refute_cacheable("/api/cacheable-cache-control-max-age/", :method => http_method)
    end
  end
end
