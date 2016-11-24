require_relative "../../../test_helper"

class Test::Apis::V1::Admins::TestIndex < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Admin.delete_all
  end

  def test_paginate_results
    FactoryGirl.create_list(:admin, 3)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admins.json?length=2", http_options.deep_merge(admin_token))
    assert_equal(200, response.code, response.body)

    admin_count = Admin.where(:deleted_at => nil).count
    assert_operator(admin_count, :>, 2)

    data = MultiJson.load(response.body)
    assert_equal(admin_count, data["recordsTotal"])
    assert_equal(admin_count, data["recordsFiltered"])
    assert_equal(2, data["data"].length)
  end
end
