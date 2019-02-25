require_relative "../test_helper"

# Deprecated API.
class Test::Apis::TestApiUsersValidate < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_valid_api_key
    user = FactoryBot.create(:api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/api-users/#{user.api_key}/validate.json", http_options)
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal({
      "status" => "valid",
    }, data)
  end

  def test_invalid_api_key
    user = FactoryBot.create(:api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/api-users/#{user.api_key}foo/validate.json", http_options)
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal({
      "status" => "invalid",
    }, data)
  end

  def test_invalid_char_api_key
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/api-users/%27/validate.json", http_options)
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal({
      "status" => "invalid",
    }, data)
  end

  def test_empty_api_key
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/api-users//validate.json", http_options)
    assert_response_code(404, response)
  end

  def test_requires_api_key
    user = FactoryBot.create(:api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/api-users/#{user.api_key}/validate.json", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end
end
