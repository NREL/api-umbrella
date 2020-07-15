require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedPresence < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  [:servers, :url_matches].each do |field|
    [:create, :update].each do |action|
      define_method("test_#{field}_#{action}_nil") do
        assert_embedded_presence_nil(action, field)
      end

      define_method("test_#{field}_#{action}_empty_array") do
        assert_embedded_presence_empty_array(action, field)
      end

      define_method("test_#{field}_#{action}_exists") do
        assert_embedded_presence_exists(action, field)
      end
    end
  end

  private

  def assert_embedded_presence_nil(action, field)
    attributes = attributes_for(action)
    attributes[field.to_s] = nil

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({
      "base" => ["Must have at least one #{field}"],
    }, data["errors"])
  end

  def assert_embedded_presence_empty_array(action, field)
    attributes = attributes_for(action)
    attributes[field.to_s] = []

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({
      "base" => ["Must have at least one #{field}"],
    }, data["errors"])
  end

  def assert_embedded_presence_exists(action, field)
    attributes = attributes_for(action)
    attributes[field.to_s] = [FactoryBot.attributes_for(:"api_backend_#{field.to_s.singularize}")]

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = ApiBackend.find(data["api"]["id"])
    when :update
      assert_response_code(204, response)
      api = ApiBackend.find(attributes["id"])
    end
    assert_equal(1, api.send(field).length)
  end

  def attributes_for(action)
    case action
    when :create
      FactoryBot.attributes_for(:api_backend).deep_stringify_keys
    when :update
      FactoryBot.create(:api_backend).serializable_hash
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end

  def create_or_update(action, attributes)
    case action
    when :create
      Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    when :update
      Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end
end
