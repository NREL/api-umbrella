require_relative "../../../test_helper"

class Test::Apis::V1::AdminPermissions::TestIndex < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_all_permissions_in_display_order
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/admin_permissions.json", http_options.deep_merge(admin_token))

    data = MultiJson.load(response.body)
    permission_names = data["admin_permissions"].map { |permission| permission["name"] }
    assert_equal([
      "Analytics",
      "API Users - View",
      "API Users - Manage",
      "Admin Accounts - View",
      "Admin Accounts - Manage",
      "API Backend Configuration - View & Manage",
      "API Backend Configuration - Publish",
    ], permission_names)

    assert_equal("analytics", data["admin_permissions"].first["id"])
    assert_equal("Analytics", data["admin_permissions"].first["name"])
    assert_equal(1, data["admin_permissions"].first["display_order"])
  end
end
