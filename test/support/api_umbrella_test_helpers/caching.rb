module ApiUmbrellaTestHelpers
  module Caching
    private

    def make_duplicate_requests(path, options = {}, second_request_options = {})
      http_opts = http_options.deep_merge({
        :params => {
          :unique_test_id => unique_test_id,
        },
      }).deep_merge(options)

      first = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_opts).run
      assert_equal(200, first.code, first.body)
      assert(first.headers["x-unique-output"])
      assert(first.headers["x-cache"])
      if(options[:method])
        assert_equal(options[:method], first.headers["x-received-method"])
      end

      second = Typhoeus::Request.new("http://127.0.0.1:9080#{path}", http_opts.deep_merge(second_request_options)).run
      assert_equal(200, second.code, second.body)
      assert(second.headers["x-unique-output"])
      assert(second.headers["x-cache"])
      if(options[:method])
        assert_equal(options[:method], second.headers["x-received-method"])
      end

      [first, second]
    end

    def assert_cacheable(path, options = {}, second_request_options = {})
      first, second = make_duplicate_requests(path, options, second_request_options)
      assert_equal("MISS", first.headers["x-cache"])
      assert_equal("HIT", second.headers["x-cache"])
      assert_equal(first.headers["x-unique-output"], second.headers["x-unique-output"])
    end

    def refute_cacheable(path, options = {}, second_request_options = {})
      first, second = make_duplicate_requests(path, options, second_request_options)
      assert_equal("MISS", first.headers["x-cache"])
      assert_equal("MISS", second.headers["x-cache"])
      refute_equal(first.headers["x-unique-output"], second.headers["x-unique-output"])
    end
  end
end
