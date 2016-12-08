require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  def test_paginate_results
    FactoryGirl.create_list(:api_user, 10)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json?length=2", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    user_count = ApiUser.where(:deleted_at => nil).count
    assert_operator(user_count, :>, 10)

    data = MultiJson.load(response.body)
    assert_equal(user_count, data["recordsTotal"])
    assert_equal(user_count, data["recordsFiltered"])
    assert_equal(2, data["data"].length)
  end

  def test_includes_api_key_preview_not_full_api_key
    api_user = FactoryGirl.create(:api_user)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    user = data["data"].find { |u| u["id"] == api_user.id }
    refute_includes(user.keys, "api_key")
    refute_includes(user.keys, "api_key_hides_at")
    assert_equal("#{api_user.api_key[0, 6]}...", user["api_key_preview"])
  end

  def test_search_first_name
    assert_wildcard_case_insensitive_search(:first_name, "FirstNameSearchTest", "IRSTNAMEsearchT")
  end

  def test_search_last_name
    assert_wildcard_case_insensitive_search(:last_name, "LastNameSearchTest", "astnamesearcht")
  end

  def test_search_email
    assert_wildcard_case_insensitive_search(:email, "EmailSearchTest@example.com", "mailsearchtest@example")
  end

  def test_search_api_key
    assert_wildcard_case_insensitive_search(:api_key, "API_KEY_SEARCH_TEST", "_key_search_tes")
  end

  def test_search_registration_source
    assert_wildcard_case_insensitive_search(:registration_source, "RegistrationSourceSearchTest", "registrationsourcesearchtest")
  end

  def test_search_roles
    assert_wildcard_case_insensitive_search(:roles, ["RoleSearchTest1", "RoleSearchTest2", "RoleSearchTest3"], "olesearchtest3")
  end

  def test_search_id
    assert_wildcard_case_insensitive_search(:id, "381f2ad2-493b-4750-994d-a046fa6eae70", "994D-A046")
  end

  private

  def assert_wildcard_case_insensitive_search(field, value, search)
    api_user = FactoryGirl.create(:api_user, field => value)
    assert_wildcard_case_insensitive_search_match(field, value, search, api_user)
    refute_wildcard_case_insensitive_search_match(field, value, "#{search}extra", api_user)
  end

  def assert_wildcard_case_insensitive_search_match(field, value, search, api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => search },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(1, data["recordsTotal"])
    assert_equal(1, data["data"].length)
    assert_equal(api_user.id, data["data"].first["id"])
  end

  def refute_wildcard_case_insensitive_search_match(field, value, search, api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :params => {
        :search => { :value => search },
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["recordsTotal"])
    assert_equal(0, data["data"].length)
  end
end
