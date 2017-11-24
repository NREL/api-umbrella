require_relative "../test_helper"

class Test::Proxy::TestDatabaseSeeding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_api_key_for_static_site
    users = ApiUser.where(:email => "static.site.ajax@internal.apiumbrella").all
    assert_equal(1, users.length)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{users.first.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    user = MultiJson.load(response.body).fetch("user")

    assert_equal("static.site.ajax@internal.apiumbrella", user["email"])
    assert_equal("API Umbrella Static Site", user["first_name"])
    assert_equal("Key", user["last_name"])
    assert_equal("seed", user["registration_source"])
    assert_equal(["api-umbrella-key-creator", "api-umbrella-contact-form"].sort, user["roles"].sort)
    assert_equal("An API key for the API Umbrella static website to use for ajax requests.", user["use_description"])
    assert_match(/\A[0-9a-f\-]{36}\z/, user["id"])
    assert_match_iso8601(user["created_at"])
    assert_match_iso8601(user["updated_at"])
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user["api_key"])
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["id"])
    assert_equal("custom", user["settings"]["rate_limit_mode"])
    assert_equal(5000, user["settings"]["rate_limits"][0]["accuracy"])
    assert_equal(60000, user["settings"]["rate_limits"][0]["duration"])
    assert_equal(5, user["settings"]["rate_limits"][0]["limit"])
    assert_equal("ip", user["settings"]["rate_limits"][0]["limit_by"])
    assert_equal(false, user["settings"]["rate_limits"][0]["response_headers"])
    assert_equal(60000, user["settings"]["rate_limits"][1]["accuracy"])
    assert_equal(3600000, user["settings"]["rate_limits"][1]["duration"])
    assert_equal(20, user["settings"]["rate_limits"][1]["limit"])
    assert_equal("ip", user["settings"]["rate_limits"][1]["limit_by"])
    assert_equal(true, user["settings"]["rate_limits"][1]["response_headers"])
  end

  def test_api_key_for_admin
    users = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").all
    assert_equal(1, users.length)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{users.first.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    user = MultiJson.load(response.body).fetch("user")

    assert_equal("web.admin.ajax@internal.apiumbrella", user["email"])
    assert_equal("API Umbrella Admin", user["first_name"])
    assert_equal("Key", user["last_name"])
    assert_equal("seed", user["registration_source"])
    assert_equal(["api-umbrella-key-creator"], user["roles"])
    assert_equal("An API key for the API Umbrella admin to use for internal ajax requests.", user["use_description"])
    assert_match(/\A[0-9a-f\-]{36}\z/, user["id"])
    assert_match_iso8601(user["created_at"])
    assert_match_iso8601(user["updated_at"])
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user["api_key"])
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["id"])
    assert_equal("unlimited", user["settings"]["rate_limit_mode"])
  end

  def test_admin_permission_records
    permissions = AdminPermission.all
    assert_equal(6, permissions.length)

    assert_equal([
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ].sort, permissions.map { |p| p.id }.sort)

    assert_equal([
      "Analytics",
      "API Users - View",
      "API Users - Manage",
      "Admin Accounts - View & Manage",
      "API Backend Configuration - View & Manage",
      "API Backend Configuration - Publish",
    ].sort, permissions.map { |p| p.name }.sort)

    permission = permissions[0].attributes
    assert_kind_of(String, permission["id"])
    assert_kind_of(String, permission["name"])
    assert_kind_of(Numeric, permission["display_order"])
    assert_kind_of(Time, permission["created_at"])
    assert_kind_of(Time, permission["updated_at"])
  end
end
