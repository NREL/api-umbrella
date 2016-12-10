require_relative "../../test_helper"

class Test::Apis::Admin::TestAuth < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_unauthenticated
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options)
    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)

    assert_equal([
      "authenticated",
      "enable_beta_analytics",
    ].sort, data.keys.sort)

    assert_includes([TrueClass, FalseClass], data["authenticated"].class)
    assert_includes([TrueClass, FalseClass], data["enable_beta_analytics"].class)

    assert_equal(false, data["authenticated"])
  end

  def test_authenticated
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options.deep_merge(admin_session))
    assert_response_code(200, response)
    body = response.body
    data = MultiJson.load(body)

    assert_equal([
      "admin",
      "api_key",
      "api_umbrella_version",
      "authenticated",
      "csrf_token",
      "enable_beta_analytics",
    ].sort, data.keys.sort)

    assert_kind_of(Hash, data["admin"])
    assert_kind_of(String, data["api_key"])
    assert_kind_of(String, data["api_umbrella_version"])
    assert_includes([TrueClass, FalseClass], data["authenticated"].class)
    assert_kind_of(String, data["csrf_token"])
    assert_includes([TrueClass, FalseClass], data["enable_beta_analytics"].class)

    assert_equal([
      "created_at",
      "created_by",
      "current_sign_in_at",
      "current_sign_in_ip",
      "deleted_at",
      "email",
      "group_ids",
      "group_names",
      "id",
      "last_sign_in_at",
      "last_sign_in_ip",
      "last_sign_in_provider",
      "name",
      "notes",
      "sign_in_count",
      "superuser",
      "updated_at",
      "updated_by",
      "username",
      "version",
    ].sort, data["admin"].keys.sort)
    assert_equal(File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip, data["api_umbrella_version"])
    assert_equal(true, data["authenticated"])
  end

  def test_authenticated_no_cross_site_access
    response = Typhoeus.get("https://127.0.0.1:9081/admin/auth", keyless_http_options.deep_merge(admin_session))
    assert_response_code(200, response)
    assert_equal("SAMEORIGIN", response.headers["X-Frame-Options"])
    assert_equal("max-age=0, private, must-revalidate", response.headers["Cache-Control"])
    assert_nil(response.headers["Access-Control-Allow-Credentials"])
  end
end
