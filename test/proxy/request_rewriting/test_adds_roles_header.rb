require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestAddsRolesHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_adds_roles_header
    user = FactoryGirl.create(:api_user, :roles => ["private"])
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal("private", data["headers"]["x-api-roles"])
  end

  def test_omits_roles_header_if_empty
    refute(self.api_user.roles)
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options)
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    refute(data["headers"]["x-api-roles"])
  end

  def test_comma_delimits_multiple_roles
    user = FactoryGirl.create(:api_user, :roles => ["private", "foo", "bar"])
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal("private,foo,bar", data["headers"]["x-api-roles"])
  end

  def test_strips_forged_values
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-Api-Roles" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    refute(data["headers"]["x-api-roles"])
    refute_match("bogus-value", response.body)
  end

  def test_strips_forged_values_case_insensitively
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-API-ROLES" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    refute(data["headers"]["x-api-roles"])
    refute_match("bogus-value", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "X-API-ROLES" => "bogus-value",
      },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    refute(data["headers"]["x-api-roles"])
    refute_match("bogus-value", response.body)
  end
end
