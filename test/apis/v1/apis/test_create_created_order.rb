require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestCreateCreatedOrder < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server

    # Reset the sequence between every test run to test sequence behavior.
    DatabaseDeleter.connection.execute("ALTER SEQUENCE api_backends_created_order_seq RESTART WITH 1")
  end

  def test_starts_at_1
    attributes = FactoryBot.attributes_for(:api_backend)
    (1..3).each do |i|
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      assert_equal(i, data["api"]["created_order"])
    end
  end

  def test_saves_when_created_order_is_null
    attributes = FactoryBot.attributes_for(:api_backend, :created_order => nil)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["api"]["created_order"])
  end

  def test_ignores_pre_set_created_order
    attributes = FactoryBot.attributes_for(:api_backend, :created_order => 8)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["api"]["created_order"])
  end
end
