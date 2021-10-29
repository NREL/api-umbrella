require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestSaveEmbeddedYaml < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  [:metadata].each do |field|
    [:create, :update].each do |action|
      define_method("test_#{field}_#{action}_invalid_yaml") do
        assert_embedded_yaml_invalid_yaml(action, field)
      end

      define_method("test_#{field}_#{action}_non_hash") do
        assert_embedded_yaml_non_hash(action, field)
      end

      define_method("test_#{field}_#{action}_null") do
        assert_embedded_yaml_null(action, field)
      end

      define_method("test_#{field}_#{action}_empty_string") do
        assert_embedded_yaml_empty_string(action, field)
      end

      define_method("test_#{field}_#{action}_valid") do
        assert_embedded_yaml_valid(action, field)
      end

      define_method("test_#{field}_#{action}_json") do
        assert_json_data(action, field)
      end
    end
  end

  private

  def assert_embedded_yaml_invalid_yaml(action, field)
    attributes = attributes_for(action)
    attributes["#{field}_yaml_string"] = "foo: &"

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "errors" => [{
        "code" => "INVALID_INPUT",
        "field" => "#{field}_yaml_string",
        "message" => "YAML parsing error: 1:1: did not find expected alphabetic or numeric character",
        "full_message" => "Metadata: YAML parsing error: 1:1: did not find expected alphabetic or numeric character",
      }],
    }, data)
  end

  def assert_embedded_yaml_non_hash(action, field)
    attributes = attributes_for(action)
    attributes["#{field}_yaml_string"] = "foo"

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "errors" => [{
        "code" => "INVALID_INPUT",
        "field" => field.to_s,
        "message" => "unexpected type (must be a hash)",
        "full_message" => "Metadata: unexpected type (must be a hash)",
      }],
    }, data)
  end

  def assert_embedded_yaml_null(action, field)
    attributes = attributes_for(action)
    attributes["#{field}_yaml_string"] = nil

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
    when :update
      assert_response_code(200, response)
      user = ApiUser.find(attributes["id"])
    end
    assert_nil(user[field])
  end

  def assert_embedded_yaml_empty_string(action, field)
    attributes = attributes_for(action)
    attributes["#{field}_yaml_string"] = ""

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
    when :update
      assert_response_code(200, response)
      user = ApiUser.find(attributes["id"])
    end
    assert_nil(user[field])
  end

  def assert_embedded_yaml_valid(action, field)
    attributes = attributes_for(action)
    attributes["#{field}_yaml_string"] = "z: 1\nstatus_code: 422\nfoo: bar\ng: true\nb: 2\na: 3"

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
    when :update
      assert_response_code(200, response)
      user = ApiUser.find(attributes["id"])
    end
    assert_equal({
      "a" => 3,
      "b" => 2,
      "foo" => "bar",
      "g" => true,
      "status_code" => 422,
      "z" => 1,
    }, user[field])

    # Check how the saved input is then output in the YAML string fields. Since
    # the data is stored unsorted (due to JSONB storage), we always sort the
    # output in alphabetical order of keys.
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "a" => 3,
      "b" => 2,
      "foo" => "bar",
      "g" => true,
      "status_code" => 422,
      "z" => 1,
    }, data.fetch("user").fetch(field.to_s))
    assert_equal("a: 3\nb: 2\nfoo: bar\ng: true\nstatus_code: 422\nz: 1", data.fetch("user").fetch("#{field}_yaml_string"))
  end

  def assert_json_data(action, field)
    attributes = attributes_for(action)
    attributes[field] = {
      :z => 1,
      :status_code => 422,
      :foo => "bar",
      :g => true,
      :b => 2,
      :a => 3,
    }

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
    when :update
      assert_response_code(200, response)
      user = ApiUser.find(attributes["id"])
    end
    assert_equal({
      "a" => 3,
      "b" => 2,
      "foo" => "bar",
      "g" => true,
      "status_code" => 422,
      "z" => 1,
    }, user[field])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "a" => 3,
      "b" => 2,
      "foo" => "bar",
      "g" => true,
      "status_code" => 422,
      "z" => 1,
    }, data.fetch("user").fetch(field.to_s))
    assert_equal("a: 3\nb: 2\nfoo: bar\ng: true\nstatus_code: 422\nz: 1", data.fetch("user").fetch("#{field}_yaml_string"))
  end

  def attributes_for(action)
    case action
    when :create
      FactoryBot.attributes_for(:api_user).deep_stringify_keys
    when :update
      FactoryBot.create(:api_user).serializable_hash
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end

  def create_or_update(action, attributes)
    case action
    when :create
      Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => attributes),
      }))
    when :update
      Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => attributes),
      }))
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end
end
