require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedYaml < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_validate_error_data_yaml_strings
    assert_embedded_yaml(:error_data)
  end

  private

  def assert_embedded_yaml(field)
    assert_embedded_yaml_create(field)
    assert_embedded_yaml_update(field)
  end

  def assert_embedded_yaml_create(field)
    assert_embedded_yaml_action(:create, field)
  end

  def assert_embedded_yaml_update(field)
    assert_embedded_yaml_action(:update, field)
  end

  def assert_embedded_yaml_action(action, field)
    assert_embedded_yaml_invalid_yaml(action, field)
    assert_embedded_yaml_non_hash(action, field)
    assert_embedded_yaml_valid(action, field)
  end

  def assert_embedded_yaml_invalid_yaml(action, field)
    attributes = attributes_for(action)
    attributes["settings"] = FactoryBot.attributes_for(:api_setting, {
      :"#{field}_yaml_strings" => {
        :api_key_invalid => "foo: &",
        :api_key_missing => "foo: bar\nhello: `world",
      },
    }).deep_stringify_keys

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({
      "settings.#{field}_yaml_strings.api_key_invalid" => ["YAML parsing error: (<unknown>): did not find expected alphabetic or numeric character while scanning an anchor at line 1 column 6"],
      "settings.#{field}_yaml_strings.api_key_missing" => ["YAML parsing error: (<unknown>): found character that cannot start any token while scanning for the next token at line 2 column 8"],
    }, data["errors"])
  end

  def assert_embedded_yaml_non_hash(action, field)
    attributes = attributes_for(action)
    attributes["settings"] = FactoryBot.attributes_for(:api_setting, {
      :"#{field}_yaml_strings" => {
        :api_key_invalid => "foo",
      },
    }).deep_stringify_keys

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({
      "settings.#{field}.api_key_invalid" => ["unexpected type (must be a hash)"],
    }, data["errors"])
  end

  def assert_embedded_yaml_valid(action, field)
    attributes = attributes_for(action)
    attributes["settings"] = FactoryBot.attributes_for(:api_setting, {
      :"#{field}_yaml_strings" => {
        :api_key_invalid => "status_code: 422\nfoo: bar",
      },
    }).deep_stringify_keys

    response = create_or_update(action, attributes)
    if(action == :create)
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = Api.find(data["api"]["id"])
    elsif(action == :update)
      assert_response_code(204, response)
      api = Api.find(attributes["id"])
    end
    assert_equal({
      "api_key_invalid" => {
        "status_code" => 422,
        "foo" => "bar",
      },
    }, api.settings[field])
  end

  def attributes_for(action)
    if(action == :create)
      FactoryBot.attributes_for(:api).deep_stringify_keys
    elsif(action == :update)
      FactoryBot.create(:api).serializable_hash
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end

  def create_or_update(action, attributes)
    if(action == :create)
      Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    elsif(action == :update)
      Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end
end
