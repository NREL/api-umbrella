require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedPresence < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_validate_servers_presence
    assert_embedded_presence(:servers)
  end

  def test_validate_url_matches_presence
    assert_embedded_presence(:url_matches)
  end

  private

  def assert_embedded_presence(field)
    assert_embedded_presence_create(field)
    assert_embedded_presence_update(field)
  end

  def assert_embedded_presence_create(field)
    assert_embedded_presence_action(:create, field)
  end

  def assert_embedded_presence_update(field)
    assert_embedded_presence_action(:update, field)
  end

  def assert_embedded_presence_action(action, field)
    assert_embedded_presence_nil(action, field)
    assert_embedded_presence_empty_array(action, field)
    assert_embedded_presence_exists(action, field)
  end

  def assert_embedded_presence_nil(action, field)
    attributes = attributes_for(action)
    attributes[field.to_s] = nil

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({
      "base" => ["must have at least one #{field}"],
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
      "base" => ["must have at least one #{field}"],
    }, data["errors"])
  end

  def assert_embedded_presence_exists(action, field)
    attributes = attributes_for(action)
    attributes[field.to_s] = [FactoryBot.attributes_for(:"api_#{field.to_s.singularize}")]

    response = create_or_update(action, attributes)
    if(action == :create)
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = Api.find(data["api"]["id"])
    elsif(action == :update)
      assert_response_code(204, response)
      api = Api.find(attributes["id"])
    end
    assert_equal(1, api[field].length)
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
