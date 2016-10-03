require "test_helper"

class TestApisV1ApisShow < Minitest::Capybara::Test
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    Api.delete_all
  end

  def test_request_headers
    assert_headers_field(:headers)
  end

  def test_response_default_headers
    assert_headers_field(:default_response_headers)
  end

  def test_response_override_headers
    assert_headers_field(:override_response_headers)
  end

  def test_embedded_custom_rate_limit_object
    api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.build(:custom_rate_limit_api_setting),
    })
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", @@http_options.deep_merge(admin_token))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal(1, data["api"]["settings"]["rate_limits"].length)
    rate_limit = data["api"]["settings"]["rate_limits"].first
    assert_equal([
      "id",
      "accuracy",
      "distributed",
      "duration",
      "limit",
      "limit_by",
      "response_headers",
    ].sort, rate_limit.keys.sort)
    assert_match(/\A[0-9a-f\-]{36}\z/, rate_limit["id"])
    assert_equal(5000, rate_limit["accuracy"])
    assert_equal(true, rate_limit["distributed"])
    assert_equal(60000, rate_limit["duration"])
    assert_equal(500, rate_limit["limit"])
    assert_equal("ip", rate_limit["limit_by"])
    assert_equal(true, rate_limit["response_headers"])
  end

  private

  def assert_headers_field(field)
    assert_headers_field_no_headers(field)
    assert_headers_field_single_header(field)
    assert_headers_field_multiple_headers(field)
  end

  def assert_headers_field_no_headers(field)
    api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
      }),
    })
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", @@http_options.deep_merge(admin_token))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("", data["api"]["settings"]["#{field}_string"])
    assert_equal(nil, data["api"]["settings"][field.to_s])
  end

  def assert_headers_field_single_header(field)
    api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :"#{field}" => [
          FactoryGirl.attributes_for(:api_header, { :key => "X-Add1", :value => "test1" }),
        ],
      }),
    })
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", @@http_options.deep_merge(admin_token))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("X-Add1: test1", data["api"]["settings"]["#{field}_string"])
    assert_kind_of(Array, data["api"]["settings"][field.to_s])
    assert_equal(1, data["api"]["settings"][field.to_s].length)
    assert_equal(["id", "key", "value"], data["api"]["settings"][field.to_s][0].keys.sort)
    assert_equal("X-Add1", data["api"]["settings"][field.to_s][0]["key"])
    assert_equal("test1", data["api"]["settings"][field.to_s][0]["value"])
  end

  def assert_headers_field_multiple_headers(field)
    api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :"#{field}" => [
          FactoryGirl.attributes_for(:api_header, { :key => "X-Add1", :value => "test1" }),
          FactoryGirl.attributes_for(:api_header, { :key => "X-Add2", :value => "test2" }),
        ],
      }),
    })
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", @@http_options.deep_merge(admin_token))
    assert_equal(200, response.code, response.body)

    data = MultiJson.load(response.body)
    assert_equal("X-Add1: test1\nX-Add2: test2", data["api"]["settings"]["#{field}_string"])
    assert_kind_of(Array, data["api"]["settings"][field.to_s])
    assert_equal(2, data["api"]["settings"][field.to_s].length)
    assert_equal("X-Add1", data["api"]["settings"][field.to_s][0]["key"])
    assert_equal("test1", data["api"]["settings"][field.to_s][0]["value"])
    assert_equal("X-Add2", data["api"]["settings"][field.to_s][1]["key"])
    assert_equal("test2", data["api"]["settings"][field.to_s][1]["value"])
  end
end
