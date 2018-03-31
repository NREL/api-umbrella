require_relative "../test_helper"

class Test::AdminUi::TestAdminGroups < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server

    AdminGroup.delete_all
    ApiScope.delete_all
  end

  def test_create
    api_scope = FactoryBot.create(:api_scope, :name => "Example Scope")

    admin_login
    visit("/admin/#/admin_groups/new")

    fill_in("Group Name", :with => "Example")
    check("Example Scope")
    check("Analytics")

    click_button("Save")
    assert_text("Successfully saved")

    admin_group = AdminGroup.desc(:created_at).first
    assert_equal("Example", admin_group.name)
    assert_equal([api_scope.id], admin_group.api_scope_ids)
    assert_equal(["analytics"], admin_group.permission_ids)
  end

  def test_update
    api_scope1 = FactoryBot.create(:api_scope, :name => "Example Scope 1")
    api_scope2 = FactoryBot.create(:api_scope, :name => "Example Scope 2")
    admin_group = FactoryBot.create(:admin_group, {
      :name => "Example",
      :api_scopes => [api_scope1],
    })

    admin_login
    visit("/admin/#/admin_groups/#{admin_group.id}/edit")

    assert_field("Group Name", :with => "Example")
    assert_checked_field("Example Scope 1")
    assert_unchecked_field("Example Scope 2")
    assert_checked_field("Analytics")
    assert_checked_field("API Users - View")
    assert_checked_field("API Users - Manage")
    assert_checked_field("Admin Accounts - View & Manage")
    assert_checked_field("API Backend Configuration - View & Manage")
    assert_checked_field("API Backend Configuration - Publish")

    fill_in("Group Name", :with => "Example2")
    uncheck("Example Scope 1")
    check("Example Scope 2")
    uncheck("API Backend Configuration - Publish")

    click_button("Save")
    assert_text("Successfully saved")

    admin_group.reload
    assert_equal("Example2", admin_group.name)
    assert_equal([api_scope2.id], admin_group.api_scope_ids)
    assert_equal([
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
    ].sort, admin_group.permission_ids.sort)
  end
end
