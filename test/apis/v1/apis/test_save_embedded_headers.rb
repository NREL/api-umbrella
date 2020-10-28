require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveEmbeddedHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  [:headers, :default_response_headers, :override_response_headers].each do |field|
    [:create, :update, :update_clears_existing_headers].each do |action|
      define_method("test_#{field}_#{action}_string_null") do
        assert_string_field_null(action, field)
      end

      define_method("test_#{field}_#{action}_string_empty") do
        assert_string_field_empty_string(action, field)
      end

      define_method("test_#{field}_#{action}_string_single") do
        assert_string_field_parses_single_header(action, field)
      end

      define_method("test_#{field}_#{action}_string_multiple") do
        assert_string_field_parses_multiple_headers(action, field)
      end

      define_method("test_#{field}_#{action}_string_extra_whitespace") do
        assert_string_field_strips_extra_whitespace(action, field)
      end

      define_method("test_#{field}_#{action}_string_values_with_colons") do
        assert_string_field_parses_values_with_colons(action, field)
      end

      define_method("test_#{field}_#{action}_array_null") do
        assert_array_field_null(action, field)
      end

      define_method("test_#{field}_#{action}_array_empty") do
        assert_array_field_empty_array(action, field)
      end

      define_method("test_#{field}_#{action}_array_of_objects") do
        assert_array_field_array_of_objects(action, field)
      end
    end
  end

  private

  def assert_string_field_null(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => nil,
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal([], db_value)

    api_value = data["api"]["settings"][field.to_s]
    assert_equal([], api_value)

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("", api_string_value)
  end

  def assert_string_field_empty_string(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => "",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal([], db_value)

    api_value = data["api"]["settings"][field.to_s]
    assert_equal([], api_value)

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("", api_string_value)
  end

  def assert_string_field_parses_single_header(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => "X-Add1: test1",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal(1, db_value.length)
    assert_equal(["X-Add1"], db_value.map { |h| h.key })

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("X-Add1: test1", api_string_value)
  end

  def assert_string_field_parses_multiple_headers(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => "X-Add1: test1\nX-Add2: test2",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal(2, db_value.length)
    assert_equal(["X-Add1", "X-Add2"], db_value.map { |h| h.key })

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("X-Add1: test1\nX-Add2: test2", api_string_value)
  end

  def assert_string_field_strips_extra_whitespace(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => "\n\n  X-Add1:test1\n\n\nX-Add2:     test2   \n\n",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal(2, db_value.length)
    assert_equal(["X-Add1", "X-Add2"], db_value.map { |h| h.key })

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("X-Add1: test1\nX-Add2: test2", api_string_value)
  end

  def assert_string_field_parses_values_with_colons(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        :"#{field}_string" => "X-Add1: test1:test2",
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete(field.to_s)

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal(1, db_value.length)
    assert_equal(["X-Add1"], db_value.map { |h| h.key })

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("X-Add1: test1:test2", api_string_value)
  end

  def assert_array_field_null(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        field.to_s => nil,
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete("#{field}_string")

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal([], db_value)

    api_value = data["api"]["settings"][field.to_s]
    assert_equal([], api_value)

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("", api_string_value)
  end

  def assert_array_field_empty_array(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
        field.to_s => [],
      }),
    }.deep_stringify_keys)
    attributes["settings"].delete("#{field}_string")

    api, data = create_or_update(action, attributes)

    db_value = api.settings.send(field)
    assert_equal([], db_value)

    api_value = data["api"]["settings"][field.to_s]
    assert_equal([], api_value)

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("", api_string_value)
  end

  def assert_array_field_array_of_objects(action, field)
    attributes = attributes_for(action, field)
    attributes.deep_merge!({
      :settings => FactoryBot.attributes_for(:api_backend_settings, {
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

    db_value = api.settings.send(field)
    assert_equal(2, db_value.length)
    assert_equal(["X-Add1", "X-Add2"], db_value.map { |h| h.key })

    api_string_value = data["api"]["settings"]["#{field}_string"]
    assert_equal("X-Add1: test1\nX-Add2: test2", api_string_value)
  end

  def attributes_for(action, field)
    case action
    when :create
      attributes = FactoryBot.attributes_for(:api_backend).deep_stringify_keys
    when :update
      api = FactoryBot.create(:api_backend, {
        :settings => FactoryBot.build(:api_backend_settings),
      })

      db_value = api.settings.send(field)
      assert_equal(0, db_value.length)

      attributes = api.serializable_hash
    when :update_clears_existing_headers
      api = FactoryBot.create(:api_backend, {
        :settings => FactoryBot.build(:api_backend_settings, {
          :"#{field}" => [
            FactoryBot.build(:api_backend_http_header, { :key => "X-Pre1", :value => "test1" }),
          ],
        }),
      })

      db_value = api.settings.send(field)
      assert_equal(1, db_value.length)

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
      api = ApiBackend.find(data["api"]["id"])
    elsif([:update, :update_clears_existing_headers].include?(action))
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)
      api = ApiBackend.find(attributes["id"])
    else
      flunk("Unknown action: #{action.inspect}")
    end

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)

    [api, data]
  end
end
