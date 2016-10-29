require_relative "../test_helper"

class TestProxyNginxGlobalRateLimits < Minitest::Test
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_no_limits_by_default
    hydra = Typhoeus::Hydra.new(:max_concurrency => 500)
    requests = 400.times.map do
      request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello/", self.http_options)
      hydra.queue(request)
      request
    end
    hydra.run

    assert_equal(400, requests.length)
    requests.each do |request|
      assert_equal(200, request.response.code, request.response.body)
    end
  end

  def test_ip_connection_limit
    override_config({
      "router" => {
        "global_rate_limits" => {
          "ip_connections" => 20,
        },
      },
    }, "--router") do
      hydra = Typhoeus::Hydra.new
      requests = 21.times.map do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/api/delay/2000", self.http_options)
        hydra.queue(request)
        request
      end
      hydra.run

      response_codes = requests.map { |r| r.response.code }
      assert_equal(21, response_codes.length)

      oks = response_codes.select { |c| c == 200 }.length
      over_rate_limits = response_codes.select { |c| c == 429 }.length
      assert_equal(20, oks)
      assert_equal(1, over_rate_limits)
    end
  end

  def test_ip_rate_limit_with_burst
    override_config({
      "router" => {
        "global_rate_limits" => {
          "ip_rate" => "10r/s",
          "ip_burst" => 20,
        },
      },
    }, "--router") do
      http_opts = self.http_options.deep_merge({
        :headers => {
          # Perform each batch of tests as though its from a unique IP address
          # so requests from different tests don't interfere with each other.
          "X-Forwarded-For" => unique_test_ip_addr,
        },
      })

      hydra = Typhoeus::Hydra.new
      requests = 40.times.map do
        request = Typhoeus::Request.new("http://127.0.0.1:9080/api/hello/", http_opts)
        hydra.queue(request)
        request
      end
      hydra.run

      response_codes = requests.map { |r| r.response.code }
      assert_equal(40, response_codes.length)

      # The rate limiting and burst handling is a bit fuzzy since we don't know
      # exactly when the initial rate limit has been exceeded (since nginx
      # limits aren't based on hard counts, but instead the average rate of
      # requests, and we also don't know how fast the tests are actually making
      # requests). Since we don't know when the burst kicks in, just make sure
      # we generally start returning over rate limit errors.
      oks = response_codes.select { |c| c == 200 }.length
      over_rate_limits = response_codes.select { |c| c == 429 }.length
      assert_operator(oks, :>=, 20)
      assert_operator(oks, :<=, 34)
      assert_operator(over_rate_limits, :>=, 1)
      assert_equal(40, oks + over_rate_limits)
    end
  end
end
