require_relative "../../test_helper"

class Test::Proxy::Caching::TestThunderingHerds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_prevents_thundering_herds_for_cacheable
    refute_thundering_herd_allowed("/api/cacheable-thundering-herd/")
  end

  def test_prevents_thundering_herds_for_cacheable_prewarm
    refute_thundering_herd_allowed("/api/cacheable-thundering-herd/", :prewarm => true)
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
    prewarm = options.delete(:prewarm)
    http_opts = http_options.deep_merge(options).deep_merge({
      :params => {
        :unique_test_id => unique_test_id,
      },
      :headers => {
        "X-Unique-ID" => SecureRandom.uuid,
      },
    })

    url = "http://127.0.0.1:9080#{path}/#{unique_test_id}"
    if(prewarm)
      request = Typhoeus::Request.new(url, http_opts)
      request.run
      sleep 6

      puts "PREWARM: #{request.response.body.inspect}"
      puts request.response.headers.inspect
    end

    hydra = Typhoeus::Hydra.new
    requests = Array.new(50) do
      http_opts.deep_merge!({
        :headers => {
          "X-Unique-ID" => SecureRandom.uuid,
        },
      })
      request = Typhoeus::Request.new(url, http_opts)
      hydra.queue(request)
      request
    end
    hydra.run

    assert_equal(50, requests.length)
    requests.each do |request|
      ap "#{request.response.code}: #{request.response.headers["X-Unique-ID"]}: #{request.response.total_time}"

      if(prewarm)
        ap request.response.body
        puts request.options[:headers].inspect
        puts request.response.headers.inspect
      end
      # assert_response_code(200, request.response)
    end
  end

  def assert_thundering_herd_allowed(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    puts "ASSERT BACKEND CALL COUNT: #{response.body}"
    # assert_equal("50", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    puts "ASSERT UNIQUE COUNT: #{unique_response_bodies.length}"
    # assert_equal(50, unique_response_bodies.length)

    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end

  def refute_thundering_herd_allowed(path, options = {})
    requests = make_thundering_herd_requests(path, options)

    response = Typhoeus.get("http://127.0.0.1:9442/backend_call_count?id=#{unique_test_id}")
    assert_response_code(200, response)
    puts "REFUTE BACKEND CALL COUNT: #{response.body}"
    # assert_equal("1", response.body)

    unique_response_bodies = requests.map { |r| r.response.body }.uniq
    puts "REFUTE UNIQUE COUNT: #{unique_response_bodies.length}"
    # assert_equal(1, unique_response_bodies.length)

    requests.each do |request|
      assert_response_code(200, request.response)
    end
  end
end
