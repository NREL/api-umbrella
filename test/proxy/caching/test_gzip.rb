require_relative "../../test_helper"

class TestProxyCachingGzip < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching
  parallelize_me!

  def setup
    setup_server
  end

  def test_caches_gzip_version
    assert_cacheable("/api/cacheable-compressible/", {
      :accept_encoding => "gzip",
    })
  end

  def test_caches_ungzip_version
    assert_cacheable("/api/cacheable-compressible/", {
      :accept_encoding => false,
    })
  end

  # Ideally we would return a cached response regardless of whether the first
  # request was gzipped or not. But for now, we don't support this, and the
  # gzip and non-gzipped versions must be requested and cached separately.
  #
  # Varnish supports this more optimized behavior, but it does so by forcing
  # gzip to always be on, then only caching the gzipped version, and then
  # un-gzipping it on the fly for each non-gzip client. For our API traffic, it
  # seems that gzip being enabled is actually the minority of requests (only
  # 40% based on some current production stats), so forcing each request to be
  # un-gzipped on the fly seems like unnecessary overhead given our current
  # usage.
  #
  # In our explorations of TrafficServer, this is unsupported:
  # http://permalink.gmane.org/gmane.comp.apache.trafficserver.user/4191
  #
  # It's possible we might want to revisit this if we decide saving the backend
  # bandwidth is more efficient than unzipping each request on the fly for each
  # non-gzip client.
  def test_separates_gzip_and_unzip_version
    refute_cacheable("/api/cacheable-compressible/", {
      :accept_encoding => "gzip",
    }, {
      :accept_encoding => false,
    })
  end

  def test_backend_gzips_itself
    assert_gzip("/api/cacheable-pre-gzip/")
  end

  def test_backend_does_not_gzip_no_vary
    assert_gzip("/api/cacheable-compressible/")
  end

  def test_backend_does_not_gzip_vary_accept_encoding
    assert_gzip("/api/cacheable-vary-accept-encoding/")
  end

  def test_backend_gzips_itself_multiple_vary
    assert_gzip("/api/cacheable-pre-gzip-multiple-vary/")
  end

  def test_backend_does_not_gzip_multiple_vary
    assert_gzip("/api/cacheable-vary-accept-encoding-multiple/")
  end

  private

  def assert_gzip(path)
    assert_first_request_gzipped_second_request_gzipped(path)
    assert_first_request_gzipped_second_request_not_gzipped(path)
    assert_first_request_not_gzipped_second_request_gzipped(path)
    assert_first_request_not_gzipped_second_request_not_gzipped(path)
  end

  def assert_first_request_gzipped_second_request_gzipped(path)
    first, second = make_duplicate_requests(path, {
      :accept_encoding => "gzip",
    })
    assert_equal("gzip", first.headers["content-encoding"])
    assert_equal("gzip", second.headers["content-encoding"])
  end

  def assert_first_request_gzipped_second_request_not_gzipped(path)
    first, second = make_duplicate_requests(path, {
      :accept_encoding => "gzip",
    }, {
      :accept_encoding => false,
    })
    assert_equal("gzip", first.headers["content-encoding"])
    refute(second.headers["content-encoding"])
  end

  def assert_first_request_not_gzipped_second_request_gzipped(path)
    first, second = make_duplicate_requests(path, {
      :accept_encoding => false,
    }, {
      :accept_encoding => "gzip",
    })
    refute(first.headers["content-encoding"])
    assert_equal("gzip", second.headers["content-encoding"])
  end

  def assert_first_request_not_gzipped_second_request_not_gzipped(path)
    first, second = make_duplicate_requests(path, {
      :accept_encoding => false,
    })
    refute(first.headers["content-encoding"])
    refute(second.headers["content-encoding"])
  end
end
