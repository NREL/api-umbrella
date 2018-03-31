require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
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

  private

  def assert_headers_field(field)
    assert_headers_field_create(field)
    assert_headers_field_update(field)
    assert_headers_field_update_clears_existing_headers(field)
  end

  def assert_headers_field_create(field)
    assert_headers_field_action(:create, field)
  end

  def assert_headers_field_update(field)
    assert_headers_field_action(:update, field)
  end

  def assert_headers_field_update_clears_existing_headers(field)
    assert_headers_field_action(:update_clears_existing_headers, field)
  end

  def assert_headers_field_action(action, field)
    assert_string_field_null(action, field)
    assert_string_field_empty_string(action, field)
    assert_string_field_parses_single_header(action, field)
    assert_string_field_parses_multiple_headers(action, field)
    assert_string_field_strips_extra_whitespace(action, field)
    assert_string_field_parses_values_with_colons(action, field)
    assert_array_field_null(action, field)
    assert_array_field_empty_array(action, field)
    assert_array_field_array_of_objects(action, field)
  end

  def assert_string_field_null(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => nil,
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    value = api.settings.send(field)
    if(value.nil?)
      assert_nil(value)
    else
      assert_equal([], value)
    end
    api_value = data["api"]["settings"][field.to_s]
    if(api_value.nil?)
      assert_nil(api_value)
    else
      assert_equal([], api_value)
    end
    assert_equal("", data["api"]["settings"]["#{field}_string"])
  end

  def assert_string_field_empty_string(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => "",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    assert_equal([], api.settings.send(field))
    assert_nil(data["api"]["settings"][field.to_s])
    assert_equal("", data["api"]["settings"]["#{field}_string"])
  end

  def assert_string_field_parses_single_header(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => "X-Add1: test1",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    assert_equal(1, api.settings.send(field).length)
    assert_equal(["X-Add1"], api.settings.send(field).map { |h| h.key })
    assert_equal("X-Add1: test1", data["api"]["settings"]["#{field}_string"])
  end

  def assert_string_field_parses_multiple_headers(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => "X-Add1: test1\nX-Add2: test2",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    assert_equal(2, api.settings.send(field).length)
    assert_equal(["X-Add1", "X-Add2"], api.settings.send(field).map { |h| h.key })
    assert_equal("X-Add1: test1\nX-Add2: test2", data["api"]["settings"]["#{field}_string"])
  end

  def assert_string_field_strips_extra_whitespace(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => "\n\n  X-Add1:test1\n\n\nX-Add2:     test2   \n\n",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    assert_equal(2, api.settings.send(field).length)
    assert_equal(["X-Add1", "X-Add2"], api.settings.send(field).map { |h| h.key })
    assert_equal("X-Add1: test1\nX-Add2: test2", data["api"]["settings"]["#{field}_string"])
  end

  def assert_string_field_parses_values_with_colons(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        :"#{field}_string" => "X-Add1: test1:test2",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)
    assert_equal(1, api.settings.send(field).length)
    assert_equal(["X-Add1"], api.settings.send(field).map { |h| h.key })
    assert_equal("X-Add1: test1:test2", data["api"]["settings"]["#{field}_string"])
  end

  def assert_array_field_null(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        field.to_s => nil,
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete("#{field}_string")

    api, data = create_or_update(action, attributes)
    assert_equal([], api.settings.send(field))
    if(action == :update_clears_existing_headers)
      assert_equal([], data["api"]["settings"][field.to_s])
    else
      assert_nil(data["api"]["settings"][field.to_s])
    end
    assert_equal("", data["api"]["settings"]["#{field}_string"])
  end

  def assert_array_field_empty_array(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        field.to_s => [],
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete("#{field}_string")

    api, data = create_or_update(action, attributes)
    assert_equal([], api.settings.send(field))
    if(action == :update_clears_existing_headers)
      assert_equal([], data["api"]["settings"][field.to_s])
    else
      assert_nil(data["api"]["settings"][field.to_s])
    end
    assert_equal("", data["api"]["settings"]["#{field}_string"])
  end

  def assert_array_field_array_of_objects(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_setting, {
        field.to_s => [
          {
            "key" => "X-Add1",
            "value" => "test1",
          },
          {
            "key" => "X-Add2",
            "value" => "test2",
          },
        ],
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete("#{field}_string")

    api, data = create_or_update(action, attributes)
    assert_equal(2, api.settings.send(field).length)
    assert_equal(["X-Add1", "X-Add2"], api.settings.send(field).map { |h| h.key })
    assert_equal("X-Add1: test1\nX-Add2: test2", data["api"]["settings"]["#{field}_string"])
  end

  def attributes_for(action, field)
    if(action == :create)
      attributes = FactoryBot.attributes_for(:api).deep_stringify_keys
    elsif(action == :update)
      api = FactoryBot.create(:api, {
        :settings => FactoryBot.attributes_for(:api_setting),
      })
      assert_equal(0, api.settings.send(field).length)
      attributes = api.serializable_hash
    elsif(action == :update_clears_existing_headers)
      api = FactoryBot.create(:api, {
        :settings => FactoryBot.attributes_for(:api_setting, {
          :"#{field}" => [
            FactoryBot.attributes_for(:api_header, { :key => "X-Pre1", :value => "test1" }),
          ],
        }),
      })
      assert_equal(1, api.settings.send(field).length)
      attributes = api.serializable_hash
    else
      flunk("Unknown action: #{action.inspect}")
    end

    attributes
  end

  def create_or_update(action, attributes)
    if(action == :create)
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = Api.find(data["api"]["id"])
    elsif(action == :update || action == :update_clears_existing_headers)
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)
      api = Api.find(attributes["id"])
    else
      flunk("Unknown action: #{action.inspect}")
    end

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)

    [api, data]
  end
end
