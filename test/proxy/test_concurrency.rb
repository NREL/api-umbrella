require_relative "../test_helper"

class Test::Proxy::TestConcurrency < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  # Fire off 20 concurrent requests and ensure that all the streamed responses
  # are proxied properly (in other words, nothing in the proxy is mishandling
  # or mixing up chunks). Just a sanity check given the async nature of all
  # this.
  def test_proxies_concurrent_requests_properly
    hydra = Typhoeus::Hydra.new
    requests = Array.new(20) do |index|
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/echo_delayed_chunked", http_options.deep_merge({
        :params => {
          :input => "#{unique_test_id}-#{index}-#{SecureRandom.hex(40)}",
        },
      }))
      hydra.queue(request)
      request
    end
    hydra.run

    assert_equal(20, requests.length)
    requests.each do |request|
      assert_response_code(200, request.response)
      assert(request.original_options[:params][:input])
      assert_equal(request.original_options[:params][:input], request.response.body)
    end
  end
end
