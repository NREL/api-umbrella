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

    puts "-DEBUG- DB user: #{users[0].ai}"
    puts "-DEBUG- DB user settings: #{users[0].settings.ai}"
    puts "-DEBUG- DB user rate_limits: #{users[0].settings.rate_limits.ai}"
    puts "-DEBUG- DB rate limits: #{RateLimit.where("api_user_settings_id IS NOT NULL").all.to_a.ai}"
    puts "-DEBUG- Audit rate limits: #{ApplicationRecord.connection.select_rows("SELECT * FROM audit.log WHERE table_name = 'rate_limits'").ai}"
    puts "-DEBUG- API user: #{user.ai}"

    assert_equal("static.site.ajax@internal.apiumbrella", user.fetch("email"))
    assert_equal("API Umbrella Static Site", user.fetch("first_name"))
    assert_equal("Key", user.fetch("last_name"))
    assert_equal("seed", user.fetch("registration_source"))
    assert_equal(["api-umbrella-key-creator", "api-umbrella-contact-form"].sort, user.fetch("roles").sort)
    assert_equal("An API key for the API Umbrella static website to use for ajax requests.", user.fetch("use_description"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user.fetch("id"))
    assert_match_iso8601(user.fetch("created_at"))
    assert_match_iso8601(user.fetch("updated_at"))
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user.fetch("api_key"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user.fetch("settings").fetch("id"))
    assert_equal("custom", user.fetch("settings").fetch("rate_limit_mode"))
    assert_nil(user.fetch("settings").fetch("rate_limits")[0].fetch("accuracy"))
    assert_equal(60000, user.fetch("settings").fetch("rate_limits")[0].fetch("duration"))
    assert_equal(5, user.fetch("settings").fetch("rate_limits")[0].fetch("limit"))
    assert_equal("ip", user.fetch("settings").fetch("rate_limits")[0].fetch("limit_by"))
    assert_equal(false, user.fetch("settings").fetch("rate_limits")[0].fetch("response_headers"))
    assert_nil(user.fetch("settings").fetch("rate_limits")[1].fetch("accuracy"))
    assert_equal(3600000, user.fetch("settings").fetch("rate_limits")[1].fetch("duration"))
    assert_equal(20, user.fetch("settings").fetch("rate_limits")[1].fetch("limit"))
    assert_equal("ip", user.fetch("settings").fetch("rate_limits")[1].fetch("limit_by"))
    assert_equal(true, user.fetch("settings").fetch("rate_limits")[1].fetch("response_headers"))
  end

  def test_api_key_for_admin
    users = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").all
    assert_equal(1, users.length)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{users.first.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    user = MultiJson.load(response.body).fetch("user")

    assert_equal("web.admin.ajax@internal.apiumbrella", user.fetch("email"))
    assert_equal("API Umbrella Admin", user.fetch("first_name"))
    assert_equal("Key", user.fetch("last_name"))
    assert_equal("seed", user.fetch("registration_source"))
    assert_equal(["api-umbrella-key-creator"], user.fetch("roles"))
    assert_equal("An API key for the API Umbrella admin to use for internal ajax requests.", user.fetch("use_description"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user.fetch("id"))
    assert_match_iso8601(user.fetch("created_at"))
    assert_match_iso8601(user.fetch("updated_at"))
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user.fetch("api_key"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user.fetch("settings").fetch("id"))
    assert_equal("unlimited", user.fetch("settings").fetch("rate_limit_mode"))
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
    assert_kind_of(String, permission.fetch("id"))
    assert_kind_of(String, permission.fetch("name"))
    assert_kind_of(Numeric, permission.fetch("display_order"))
    assert_kind_of(Time, permission.fetch("created_at"))
    assert_kind_of(Time, permission.fetch("updated_at"))
  end
end
