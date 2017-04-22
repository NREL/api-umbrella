require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveRewriteValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_valid_rewrite
    assert_valid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite),
      ],
    })
  end

  def test_rejects_null_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :matcher_type => nil),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_blank_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :matcher_type => ""),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_invalid_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :matcher_type => "zzz"),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_null_http_method
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :http_method => nil),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_blank_http_method
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :http_method => ""),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_invalid_http_method
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :http_method => "zzz"),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_null_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :frontend_matcher => nil),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_blank_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :frontend_matcher => ""),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_null_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :backend_replacement => nil),
      ],
    }, ["rewrites[0].backend_replacement"])
  end

  def test_rejects_blank_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryGirl.attributes_for(:api_rewrite, :backend_replacement => ""),
      ],
    }, ["rewrites[0].backend_replacement"])
  end

  private

  def assert_valid(overrides)
    assert_valid_create(overrides)
    assert_valid_update(overrides)
  end

  def assert_valid_create(overrides)
    assert_valid_action(:create, overrides)
  end

  def assert_valid_update(overrides)
    assert_valid_action(:update, overrides)
  end

  def assert_valid_action(action, overrides)
    attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

    response = create_or_update(action, attributes)
    if(action == :create)
      assert_response_code(201, response)
    elsif(action == :update)
      assert_response_code(204, response)
    end
  end

  def assert_invalid(overrides, expected_error_fields)
    assert_invalid_create(overrides, expected_error_fields)
    assert_invalid_update(overrides, expected_error_fields)
  end

  def assert_invalid_create(overrides, expected_error_fields)
    assert_invalid_action(:create, overrides, expected_error_fields)
  end

  def assert_invalid_update(overrides, expected_error_fields)
    assert_invalid_action(:update, overrides, expected_error_fields)
  end

  def assert_invalid_action(action, overrides, expected_error_fields)
    attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(expected_error_fields.sort, data["errors"].keys.sort)
  end

  def attributes_for(action)
    if(action == :create)
      FactoryGirl.attributes_for(:api).deep_stringify_keys
    elsif(action == :update)
      FactoryGirl.create(:api).serializable_hash
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
