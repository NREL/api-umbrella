require_relative "../../test_helper"

class Test::Apis::Admin::TestAuth < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_unauthenticated
    FactoryBot.create(:admin)
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options)
    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)

    assert_equal([
      "authenticated",
    ].sort, data.keys.sort)

    assert_equal(false, data["authenticated"])
  end

  def test_authenticated
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options.deep_merge(admin_session))
    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)

    assert_equal([
      "admin",
      "admin_contact_url",
      "analytics_timezone",
      "api_key",
      "api_umbrella_version",
      "authenticated",
      "csrf_token",
      "local_auth_enabled",
      "password_length_min",
      "username_is_email",
    ].sort, data.keys.sort)

    assert_kind_of(Hash, data["admin"])
    assert_kind_of(String, data["admin_contact_url"])
    assert_kind_of(String, data["analytics_timezone"])
    assert_kind_of(String, data["api_key"])
    assert_kind_of(String, data["api_umbrella_version"])
    assert_kind_of(String, data["csrf_token"])
    assert_includes([TrueClass, FalseClass], data["authenticated"].class)

    assert_equal([
      "email",
      "id",
      "permissions",
      "superuser",
      "username",
    ].sort, data["admin"].keys.sort)

    assert_equal([
      "admin_manage",
      "admin_view",
      "analytics",
      "backend_manage",
      "backend_publish",
      "user_manage",
      "user_view",
    ].sort, data.fetch("admin").fetch("permissions").keys.sort)

    assert_equal(File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip, data["api_umbrella_version"])
    assert_equal(true, data["authenticated"])
    data.fetch("admin").fetch("permissions").each_value do |value|
      assert_equal(true, value)
    end
  end

  def test_authenticated_no_cross_site_access
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options.deep_merge(admin_session))
    assert_response_code(200, response)
    assert_equal("DENY", response.headers["X-Frame-Options"])
    assert_equal("no-cache, max-age=0, must-revalidate, no-store", response.headers["Cache-Control"])
    assert_nil(response.headers["Access-Control-Allow-Credentials"])
  end

  def test_limited_admin_permissions
    permissions = [
      "admin_manage",
      "admin_view",
      "analytics",
      "backend_manage",
      "backend_publish",
      "user_manage",
      "user_view",
    ]

    permissions.each do |permission|
      admin = FactoryBot.create(:limited_admin, :groups => [
        FactoryBot.create(:google_admin_group, :permission_ids => [permission]),
      ])
      response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options.deep_merge(admin_session(admin)))
      assert_response_code(200, response)
      body = response.body
      data = MultiJson.load(body)

      assert_equal(permissions.sort, data.fetch("admin").fetch("permissions").keys.sort)
      permissions_by_value = {}
      data.fetch("admin").fetch("permissions").each do |auth_permission, auth_value|
        permissions_by_value[auth_value] ||= []
        permissions_by_value[auth_value] << auth_permission
      end

      assert_equal([permission], permissions_by_value.fetch(true))
      assert_equal((permissions - [permission]).sort, permissions_by_value.fetch(false).sort)
    end
  end
end
