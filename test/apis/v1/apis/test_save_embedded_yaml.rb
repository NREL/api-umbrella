require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedYaml < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  [:error_data].each do |field|
    [:create, :update].each do |action|
      define_method("test_#{field}_#{action}_invalid_yaml") do
        assert_embedded_yaml_invalid_yaml(action, field)
      end

      define_method("test_#{field}_#{action}_non_hash") do
        assert_embedded_yaml_non_hash(action, field)
      end

      define_method("test_#{field}_#{action}_valid") do
        assert_embedded_yaml_valid(action, field)
      end
    end
  end

  private

  def assert_embedded_yaml_invalid_yaml(action, field)
    attributes = attributes_for(action)
    attributes["settings"] = FactoryGirl.attributes_for(:api_backend_settings, {
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
      "settings.#{field}_yaml_strings.api_key_invalid" => ["YAML parsing error: 1:1: did not find expected alphabetic or numeric character"],
      "settings.#{field}_yaml_strings.api_key_missing" => ["YAML parsing error: 2:1: found character that cannot start any token"],
    }, data["errors"])
  end

  def assert_embedded_yaml_non_hash(action, field)
    attributes = attributes_for(action)
    attributes["settings"] = FactoryGirl.attributes_for(:api_backend_settings, {
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
    attributes["settings"] = FactoryGirl.attributes_for(:api_backend_settings, {
      :"#{field}_yaml_strings" => {
        :api_key_invalid => "status_code: 422\nfoo: bar",
      },
    }).deep_stringify_keys

    response = create_or_update(action, attributes)
    if(action == :create)
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = ApiBackend.find(data["api"]["id"])
    elsif(action == :update)
      assert_response_code(204, response)
      api = ApiBackend.find(attributes["id"])
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
      FactoryGirl.attributes_for(:api_backend).deep_stringify_keys
    elsif(action == :update)
      FactoryGirl.create(:api_backend).serializable_hash
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
