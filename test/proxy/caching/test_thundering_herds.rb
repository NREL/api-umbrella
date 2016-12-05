require_relative "../../test_helper"

class Test::Proxy::Caching::TestThunderingHerds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    setup_server
  end

  def test_prevents_thundering_herds_for_cacheable
    # FIXME: The Traffic Server collapsed_connection plugin currently requires
    # the Cache-Control explicitly be marked as "public" for it to do its
    # collapsing:
    # https://github.com/apache/trafficserver/blob/5.3.2/plugins/experimental/collapsed_connection/collapsed_connection.cc#L603
    #
    # I think this is incorrect behavior and the plugin should be updated to
    # use the newer TSHttpTxnIsCacheable API:
    # https://issues.apache.org/jira/browse/TS-1622 This will allow the plugin
    # to more accurately know whether the response is cacheable according to
    # the more complex TrafficServer logic. We should see about submitting a
    # pull request or filing an issue.
    skip("TrafficServer's collapsed_connection requires explicit public cache-control headers to work properly.")
    refute_thundering_herd_allowed("/api/cacheable-thundering-herd/")
  end

  def test_prevents_thundering_herds_for_public_cacheable
    refute_thundering_herd_allowed("/api/cacheable-thundering-herd-public/")
  end

  def test_allows_thundering_herds_for_private_cacheable
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd-private/")
  end

  def test_allows_thundering_herds_for_cache_disabled
    assert_thundering_herd_allowed("/api/cacheable-but-cache-forbidden-thundering-herd/")
  end

  def test_allows_thundering_herds_for_no_explicit_cache
    assert_thundering_herd_allowed("/api/cacheable-but-no-explicit-cache-thundering-herd/")
  end

  def test_allows_thundering_herds_for_non_cacheable
    assert_thundering_herd_allowed("/api/cacheable-thundering-herd/", :method => "POST")
  end

  private

  def make_thundering_herd_requests(path, options = {})
    http_opts = http_options.deep_merge(options).deep_merge({
      :params => {
        :unique_test_id => unique_test_id,
      },
    })

    hydra = Typhoeus::Hydra.new
    requests = Array.new(50) do
      request = Typhoeus::Request.new("http://127.0.0.1:9080#{path}/#{unique_test_id}", http_opts)
      hydra.queue(request)
      request
    end
    hydra.run

    assert_equal(50, requests.length)
    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end

  def assert_thundering_herd_allowed(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("50", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    assert_equal(50, unique_response_bodies.length)
  end

  def refute_thundering_herd_allowed(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    assert_equal("1", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    assert_equal(1, unique_response_bodies.length)
  end
end
