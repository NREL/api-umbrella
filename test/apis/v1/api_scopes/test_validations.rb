require_relative "../../../test_helper"

class Test::Apis::V1::ApiScopes::TestValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_required_create
    attributes = {}
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/api_scopes.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_all_required(response)
  end

  def test_required_update
    record = FactoryBot.create(:api_scope)

    attributes = {
      :name => nil,
      :host => nil,
      :path_prefix => nil,
    }
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/api_scopes/#{record.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api_scope => attributes),
    }))
    assert_response_all_required(response)
  end

  private

  def assert_response_all_required(response)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      "name",
      "host",
      "path_prefix",
    ].sort, data["errors"].keys.sort)
    assert_equal(["can't be blank"].sort, data["errors"]["name"].sort)
    assert_equal([
      "can't be blank",
      'must be in the format of "example.com"',
    ].sort, data["errors"]["host"].sort)
    assert_equal([
      "can't be blank",
      'must start with "/"',
    ].sort, data["errors"]["path_prefix"].sort)
  end
end
