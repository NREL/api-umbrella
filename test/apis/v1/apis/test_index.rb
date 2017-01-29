require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_datatables_output_fields
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal([
      "data",
      "draw",
      "recordsFiltered",
      "recordsTotal",
    ], data.keys.sort)
  end

  def test_paginate_results
    FactoryGirl.create_list(:api, 3)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json?length=2", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    assert_equal(3, Api.where(:deleted_at => nil).count)

    data = MultiJson.load(response.body)
    assert_equal(3, data["recordsTotal"])
    assert_equal(3, data["recordsFiltered"])
    assert_equal(2, data["data"].length)
  end
end
