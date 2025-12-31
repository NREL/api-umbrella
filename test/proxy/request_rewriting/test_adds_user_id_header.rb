require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestAddsUserIdHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds_user_id_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    assert_equal(36, data["headers"]["x-api-user-id"].length)
  end

  def test_strips_forged_values
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-Api-User-Id" => "bogus-value",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    refute_match("bogus-value", response.body)
  end

  def test_strips_forged_values_case_insensitively
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-API-USER-ID" => "bogus-value",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    refute_match("bogus-value", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "x-api-user-id" => "bogus-value",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    refute_match("bogus-value", response.body)
  end

  def test_api_keys_optional
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/api-keys-optional/", :backend_prefix => "/" }],
        :settings => {
          :disable_api_key => true,
        },
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/api-keys-optional/info/", keyless_http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      refute(data["headers"]["x-api-user-id"])

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/api-keys-optional/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
      assert_equal(36, data["headers"]["x-api-user-id"].length)
    end
  end
end
