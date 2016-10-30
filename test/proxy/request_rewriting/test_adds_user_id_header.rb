require_relative "../../test_helper"

class TestProxyRequestRewritingAddsUserIdHeader < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_adds_user_id_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", self.http_options)
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    assert_equal(36, data["headers"]["x-api-user-id"].length)
  end

  def test_passes_mongo_object_ids_as_hex_strings
    user = FactoryGirl.create(:api_user, :id => BSON::ObjectId.new)
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", self.http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(user.id, data["headers"]["x-api-user-id"])
    assert_equal(24, data["headers"]["x-api-user-id"].length)
  end

  def test_strips_forged_values
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", self.http_options.deep_merge({
      :headers => {
        "X-Api-User-Id" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    refute_match("bogus-value", response.body)
  end

  def test_strips_forged_values_case_insensitively
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", self.http_options.deep_merge({
      :headers => {
        "X-API-USER-ID" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
    refute_match("bogus-value", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", self.http_options.deep_merge({
      :headers => {
        "x-api-user-id" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
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
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/api-keys-optional/info/", self.http_options.except(:headers))
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      refute(data["headers"]["x-api-user-id"])

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/api-keys-optional/info/", self.http_options)
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal(self.api_user.id, data["headers"]["x-api-user-id"])
      assert_equal(36, data["headers"]["x-api-user-id"].length)
    end
  end
end
