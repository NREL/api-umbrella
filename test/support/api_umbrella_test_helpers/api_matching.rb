module ApiUmbrellaTestHelpers
  module ApiMatching
    private

    def make_request_to_host(host, path, options = {})
      Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge(options).deep_merge({
        :headers => {
          "Host" => host,
        },
      }))
    end

    def assert_backend_match(backend, response)
      assert_equal(200, response.code, response.body)
      assert_equal("application/json", response.headers["content-type"])
      data = MultiJson.load(response.body)
      assert_equal(backend, data["headers"]["x-backend"])
    end
  end
end
