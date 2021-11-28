module ApiUmbrellaTestHelpers
  module ApiMatching
    private

    def make_request_to_host(host, path, options = {})
      Typhoeus.get("https://127.0.0.1:9081#{path}", http_options.deep_merge(options).deep_merge({
        :headers => {
          "Host" => host,
        },
      }))
    end

    def assert_backend_match(backend, response)
      assert_response_code(200, response)
      assert_equal("application/json", response.headers["content-type"])
      data = MultiJson.load(response.body)
      assert_equal(backend, data["headers"]["x-test-backend"])
    end

    def assert_backend_host_path_match(host, path, response)
      assert_response_code(200, response)
      assert_equal("application/json", response.headers["content-type"])
      data = MultiJson.load(response.body)
      assert_equal(host, data["url"]["host"])
      assert_equal(path, data["url"]["path"])
    end
  end
end
