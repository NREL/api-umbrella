require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestCreateSortOrder < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_start_0_increment_10000
    attributes = FactoryBot.attributes_for(:api)
    3.times do |i|
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      assert_equal(i * 10_000, data["api"]["sort_order"])
    end
  end

  def test_saves_when_sort_order_is_null
    attributes = FactoryBot.attributes_for(:api, :sort_order => nil)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["api"]["sort_order"])
  end

  def test_pre_set_sort_order
    attributes = FactoryBot.attributes_for(:api, :sort_order => 8)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(8, data["api"]["sort_order"])
  end

  def test_fills_in_sort_order_as_approaching_integer_range
    FactoryBot.create(:api, :sort_order => 2_147_483_600)

    attributes = FactoryBot.attributes_for(:api)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(2_147_483_624, data["api"]["sort_order"])

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(2_147_483_636, data["api"]["sort_order"])

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal(2_147_483_642, data["api"]["sort_order"])
  end

  def test_reshuffles_sort_order_when_integer_range_exceeded
    api1 = FactoryBot.create(:api, :sort_order => 2_147_483_000)
    api2 = FactoryBot.create(:api, :sort_order => 2_147_483_645)

    attributes = FactoryBot.attributes_for(:api)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    api3_id = data["api"]["id"]
    assert_equal(2_147_483_646, data["api"]["sort_order"])

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    api4_id = data["api"]["id"]
    assert_equal(2_147_483_647, data["api"]["sort_order"])

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    api5_id = data["api"]["id"]
    assert_equal(2_147_483_647, data["api"]["sort_order"])

    api1.reload
    api2.reload
    api3 = Api.find(api3_id)
    api4 = Api.find(api4_id)
    api5 = Api.find(api5_id)
    assert_equal(2_147_483_000, api1.sort_order)
    assert_equal(2_147_483_644, api2.sort_order)
    assert_equal(2_147_483_645, api3.sort_order)
    assert_equal(2_147_483_646, api4.sort_order)
    assert_equal(2_147_483_647, api5.sort_order)
  end
end
