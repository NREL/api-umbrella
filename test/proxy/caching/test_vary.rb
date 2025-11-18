require_relative "../../test_helper"

class Test::Proxy::Caching::TestVary < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_caches_when_non_vary_headers_differs
    assert_cacheable("/api/cacheable-cache-control-max-age/", {
      :headers => {
        "X-Custom" => "foo",
      },
    }, {
      :headers => {
        "X-Custom" => "bar",
      },
    })
  end

  def test_does_not_cache_when_vary_header_differs
    refute_cacheable("/api/cacheable-vary-x-custom/", {
      :headers => {
        "X-Custom" => "foo",
      },
    }, {
      :headers => {
        "X-Custom" => "bar",
      },
    })
  end

  def test_caches_when_vary_header_not_set
    assert_cacheable("/api/cacheable-vary-x-custom/")
  end

  def test_caches_when_vary_header_same
    assert_cacheable("/api/cacheable-vary-x-custom/", {
      :headers => {
        "X-Custom" => "foo",
      },
    })
  end

  def test_caches_when_multi_vary_same
    assert_cacheable("/api/cacheable-multiple-vary/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    })
  end

  def test_caches_when_multi_vary_non_vary_header_differs
    assert_cacheable("/api/cacheable-multiple-vary/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    }, {
      :headers => {
        "X-Bar" => "foo",
      },
    })
  end

  def test_does_not_cache_when_multi_vary_any_vary_header_differs
    refute_cacheable("/api/cacheable-multiple-vary/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    }, {
      :headers => {
        "Accept" => "application/json",
      },
    })
  end

  def test_caches_when_encoding_vary_same
    assert_cacheable("/api/cacheable-multiple-vary-with-accept-encoding/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    })
  end

  def test_caches_when_encoding_vary_non_vary_header_differs
    assert_cacheable("/api/cacheable-multiple-vary-with-accept-encoding/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    }, {
      :headers => {
        "X-Bar" => "foo",
      },
    })
  end

  def test_does_not_cache_when_encoding_vary_any_vary_header_differs
    refute_cacheable("/api/cacheable-multiple-vary-with-accept-encoding/", {
      :headers => {
        "Accept" => "text/plain",
        "Accept-Language" => "en-US",
        "X-Foo" => "bar",
      },
    }, {
      :headers => {
        "Accept" => "application/json",
      },
    })
  end
end
