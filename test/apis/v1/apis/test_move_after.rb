require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestMoveAfter < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_move_to_beginning_when_move_after_id_null
    api1 = create_with_default_sort_order
    api2 = create_with_default_sort_order
    api3 = create_with_default_sort_order
    api4 = create_with_default_sort_order

    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(20_000, api3.sort_order)
    assert_equal(30_000, api4.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => nil },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(-10_000, api3.sort_order)
    assert_equal(30_000, api4.sort_order)
  end

  def test_move_to_beginning_gap_10000
    api1 = FactoryBot.create(:api, :sort_order => 99)
    api2 = create_with_default_sort_order

    assert_equal(99, api1.sort_order)
    assert_equal(10_099, api2.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api2.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => nil },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    assert_equal(99, api1.sort_order)
    assert_equal(-9_901, api2.sort_order)
  end

  def test_moves_to_middle_without_changing_surrounding_orders
    api1 = create_with_default_sort_order
    api2 = create_with_default_sort_order
    api3 = create_with_default_sort_order

    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(20_000, api3.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(5_000, api3.sort_order)
  end

  def test_no_movement_does_not_update_evenly_distributed_orders
    api1 = create_with_default_sort_order
    api2 = create_with_default_sort_order
    api3 = create_with_default_sort_order

    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(20_000, api3.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api2.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(20_000, api3.sort_order)
  end

  def test_no_movement_updates_sort_order_if_not_evenly_distributed
    api1 = FactoryBot.create(:api, :sort_order => 0)
    api2 = FactoryBot.create(:api, :sort_order => 10_000)
    api3 = FactoryBot.create(:api, :sort_order => 100_000)

    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
    assert_equal(100_000, api3.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api2.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    assert_equal(0, api1.sort_order)
    assert_equal(50_000, api2.sort_order)
    assert_equal(100_000, api3.sort_order)
  end

  def test_no_movement_updates_sort_order_if_no_subsequent_record
    api1 = FactoryBot.create(:api, :sort_order => 0)
    api2 = FactoryBot.create(:api, :sort_order => 3_000)

    assert_equal(0, api1.sort_order)
    assert_equal(3_000, api2.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api2.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    assert_equal(0, api1.sort_order)
    assert_equal(10_000, api2.sort_order)
  end

  def test_no_gaps_reshuffles_positive_orders
    api1 = FactoryBot.create(:api, :sort_order => 0)
    api2 = FactoryBot.create(:api, :sort_order => 1)
    api3 = FactoryBot.create(:api, :sort_order => 2)
    api4 = FactoryBot.create(:api, :sort_order => 3)
    api5 = FactoryBot.create(:api, :sort_order => 10)

    assert_equal(0, api1.sort_order)
    assert_equal(1, api2.sort_order)
    assert_equal(2, api3.sort_order)
    assert_equal(3, api4.sort_order)
    assert_equal(10, api5.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    api5.reload
    assert_equal(-1, api1.sort_order)
    assert_equal(1, api2.sort_order)
    assert_equal(0, api3.sort_order)
    assert_equal(3, api4.sort_order)
    assert_equal(10, api5.sort_order)
  end

  def test_no_gaps_reshuffles_positive_orders_near_integer_limit
    api1 = FactoryBot.create(:api, :sort_order => 2_147_483_640)
    api2 = FactoryBot.create(:api, :sort_order => 2_147_483_645)
    api3 = FactoryBot.create(:api, :sort_order => 2_147_483_646)
    api4 = FactoryBot.create(:api, :sort_order => 2_147_483_647)

    assert_equal(2_147_483_640, api1.sort_order)
    assert_equal(2_147_483_645, api2.sort_order)
    assert_equal(2_147_483_646, api3.sort_order)
    assert_equal(2_147_483_647, api4.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api2.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api4.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    assert_equal(2_147_483_640, api1.sort_order)
    assert_equal(2_147_483_647, api2.sort_order)
    assert_equal(2_147_483_645, api3.sort_order)
    assert_equal(2_147_483_646, api4.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => nil },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    assert_equal(2_147_483_640, api1.sort_order)
    assert_equal(2_147_483_647, api2.sort_order)
    assert_equal(2_147_473_640, api3.sort_order)
    assert_equal(2_147_483_646, api4.sort_order)
  end

  def test_no_gaps_reshuffles_negative_orders
    api1 = FactoryBot.create(:api, :sort_order => -10)
    api2 = FactoryBot.create(:api, :sort_order => -9)
    api3 = FactoryBot.create(:api, :sort_order => -8)
    api4 = FactoryBot.create(:api, :sort_order => -7)
    api5 = FactoryBot.create(:api, :sort_order => 0)

    assert_equal(-10, api1.sort_order)
    assert_equal(-9, api2.sort_order)
    assert_equal(-8, api3.sort_order)
    assert_equal(-7, api4.sort_order)
    assert_equal(0, api5.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    api5.reload
    assert_equal(-10, api1.sort_order)
    assert_equal(-8, api2.sort_order)
    assert_equal(-9, api3.sort_order)
    assert_equal(-7, api4.sort_order)
    assert_equal(0, api5.sort_order)
  end

  def test_no_gaps_reshuffles_negative_orders_near_integer_limit
    api1 = FactoryBot.create(:api, :sort_order => -2_147_483_648)
    api2 = FactoryBot.create(:api, :sort_order => -2_147_483_647)
    api3 = FactoryBot.create(:api, :sort_order => -2_147_483_646)
    api4 = FactoryBot.create(:api, :sort_order => -2_147_483_640)

    assert_equal(-2_147_483_648, api1.sort_order)
    assert_equal(-2_147_483_647, api2.sort_order)
    assert_equal(-2_147_483_646, api3.sort_order)
    assert_equal(-2_147_483_640, api4.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => api1.id },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    assert_equal(-2_147_483_648, api1.sort_order)
    assert_equal(-2_147_483_646, api2.sort_order)
    assert_equal(-2_147_483_647, api3.sort_order)
    assert_equal(-2_147_483_640, api4.sort_order)

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api3.id}/move_after.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :move_after_id => nil },
    }))
    assert_response_code(204, response)

    api1.reload
    api2.reload
    api3.reload
    api4.reload
    assert_equal(-2_147_483_647, api1.sort_order)
    assert_equal(-2_147_483_646, api2.sort_order)
    assert_equal(-2_147_483_648, api3.sort_order)
    assert_equal(-2_147_483_640, api4.sort_order)
  end

  private

  def create_with_default_sort_order
    attributes = FactoryBot.attributes_for(:api)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :api => attributes },
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    Api.find(data["api"]["id"])
  end
end
