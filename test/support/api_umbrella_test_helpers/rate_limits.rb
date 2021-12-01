module ApiUmbrellaTestHelpers
  module RateLimits
    private

    def assert_api_key_rate_limit(path, limit, options = {})
      assert_allows_up_to_limit_and_then_rejects(path, limit, options)
      assert_counts_api_keys_separately(path, limit, options)
      assert_rate_limit_headers(path, limit, options)
    end

    def assert_ip_rate_limit(path, limit, options = {})
      assert_allows_up_to_limit_and_then_rejects(path, limit, options)
      assert_counts_ips_separately(path, limit, options)
      assert_rate_limit_headers(path, limit, options)
    end

    def assert_unlimited_rate_limit(path, limit, options = {})
      options[:no_response_headers] = true
      assert_can_exceed_limit(path, limit, options)
      assert_rate_limit_headers(path, limit, options)
    end

    def assert_allows_up_to_limit_and_then_rejects(path, limit, options = {})
      api_key = create_api_key(options)
      ip = next_unique_ip_addr
      assert_under_rate_limit(path, limit, :api_key => api_key, :ip => ip)
      assert_over_rate_limit(path, 1, :api_key => api_key, :ip => ip)
    end

    def assert_can_exceed_limit(path, limit, options)
      api_key = create_api_key(options)
      ip = next_unique_ip_addr
      assert_under_rate_limit(path, limit, :api_key => api_key, :ip => ip)
      assert_under_rate_limit(path, 1, :api_key => api_key, :ip => ip)
    end

    def assert_counts_api_keys_separately(path, limit, options = {})
      api_key = create_api_key(options)
      ip = next_unique_ip_addr
      assert_under_rate_limit(path, limit, :api_key => api_key, :ip => ip)
      assert_over_rate_limit(path, 1, :api_key => api_key, :ip => next_unique_ip_addr)
      assert_under_rate_limit(path, 1, :api_key => create_api_key(options), :ip => ip)
    end

    def assert_counts_ips_separately(path, limit, options = {})
      api_key = create_api_key(options)
      ip = next_unique_ip_addr
      assert_under_rate_limit(path, limit, :api_key => api_key, :ip => ip)
      assert_over_rate_limit(path, 1, :api_key => create_api_key(options), :ip => ip)
      assert_under_rate_limit(path, 1, :api_key => api_key, :ip => next_unique_ip_addr)
    end

    def assert_rate_limit_headers(path, limit, options = {})
      api_key = create_api_key(options)
      response = make_requests(path, 1, :api_key => api_key, :ip => next_unique_ip_addr).first

      if(options[:no_response_headers])
        refute(response.headers["x-ratelimit-limit"])
        refute(response.headers["x-ratelimit-remaining"])
      else
        expected_limit = limit
        if(options[:response_header_limit])
          expected_limit = options[:response_header_limit]
        end

        assert_equal(expected_limit.to_s, response.headers["x-ratelimit-limit"])
        assert_equal((expected_limit - 1).to_s, response.headers["x-ratelimit-remaining"])
      end
    end

    def assert_under_rate_limit(path, count, options = {})
      responses = make_requests(path, count, options)
      responses.each do |response|
        assert_response_code(200, response)
        assert_equal("Hello World", response.body)
      end
    end

    def assert_over_rate_limit(path, count, options = {})
      responses = make_requests(path, count, options)
      responses.each do |response|
        assert_response_code(429, response)
        assert_match("OVER_RATE_LIMIT", response.body)
      end
    end

    def create_api_key(options)
      api_key = nil
      unless(options[:omit_api_key])
        options[:user_factory_overrides] ||= {}
        api_key = FactoryBot.create(:api_user, options[:user_factory_overrides]).api_key
      end

      api_key
    end

    def make_requests(path, count, options = {})
      hydra_options = {}
      if options[:max_concurrency]
        hydra_options[:max_concurrency] = options.delete(:max_concurrency)
      end

      http_opts = keyless_http_options.deep_merge({
        :headers => {},
      })
      if(options[:api_key])
        http_opts[:headers]["X-Api-Key"] = options[:api_key]
      end
      if(options[:ip])
        http_opts[:headers]["X-Forwarded-For"] = options[:ip]
      end
      if(options[:time])
        http_opts[:headers]["X-Fake-Time"] = options[:time].strftime("%s%L").to_i
      end
      if(options[:http_options])
        http_opts.deep_merge!(options[:http_options])
      end

      hydra = Typhoeus::Hydra.new(hydra_options)
      requests = Array.new(count) do
        request = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_opts)
        hydra.queue(request)
        request
      end
      hydra.run

      assert_equal(count, requests.length)
      requests.map { |r| r.response }
    end
  end
end
