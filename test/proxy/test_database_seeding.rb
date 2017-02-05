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

    user = users.first.attributes
    assert_equal({
      "email" => "static.site.ajax@internal.apiumbrella",
      "first_name" => "API Umbrella Static Site",
      "last_name" => "Key",
      "registration_source" => "seed",
      "roles" => ["api-umbrella-key-creator", "api-umbrella-contact-form"],
      "terms_and_conditions" => "1",
      "use_description" => "An API key for the API Umbrella static website to use for ajax requests.",
    }, user.compact.except("_id", "created_at", "updated_at", "api_key", "settings"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user["_id"])
    assert_kind_of(Time, user["created_at"])
    assert_kind_of(Time, user["updated_at"])
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user["api_key"])

    assert_equal({
      "rate_limit_mode" => "custom",
    }, user["settings"].compact.except("_id", "rate_limits"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["_id"])

    assert_equal([
      {
        "accuracy" => 5000.0,
        "duration" => 60000.0,
        "limit" => 5.0,
        "limit_by" => "ip",
        "response_headers" => false,
      },
      {
        "accuracy" => 60000.0,
        "duration" => 3600000.0,
        "limit" => 20.0,
        "limit_by" => "ip",
        "response_headers" => true,
      },
    ], user["settings"]["rate_limits"].map { |r| r.compact.except("_id") })
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["rate_limits"][0]["_id"])
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["rate_limits"][1]["_id"])
  end

  def test_api_key_for_admin
    users = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").all
    assert_equal(1, users.length)

    user = users.first.attributes
    assert_equal({
      "email" => "web.admin.ajax@internal.apiumbrella",
      "first_name" => "API Umbrella Admin",
      "last_name" => "Key",
      "registration_source" => "seed",
      "roles" => ["api-umbrella-key-creator"],
      "terms_and_conditions" => "1",
      "use_description" => "An API key for the API Umbrella admin to use for internal ajax requests.",
    }, user.compact.except("_id", "created_at", "updated_at", "api_key", "settings"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user["_id"])
    assert_kind_of(Time, user["created_at"])
    assert_kind_of(Time, user["updated_at"])
    assert_match(/\A[a-zA-Z0-9]{40}\z/, user["api_key"])

    assert_equal({
      "rate_limit_mode" => "unlimited",
    }, user["settings"].compact.except("_id"))
    assert_match(/\A[0-9a-f\-]{36}\z/, user["settings"]["_id"])
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
    assert_kind_of(String, permission["_id"])
    assert_kind_of(String, permission["name"])
    assert_kind_of(Numeric, permission["display_order"])
    assert_kind_of(Time, permission["created_at"])
    assert_kind_of(Time, permission["updated_at"])
  end
end
