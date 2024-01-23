require_relative "../test_helper"

class Test::AdminUi::TestPermissionsNavigation < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_superuser
    admin_login

    assert_nav([
      "API Umbrella",
      "Analytics",
      "Users",
      "Configuration",
    ])

    assert_analytics_menu([
      "API Drilldown",
      "Filter Logs",
      "By Users",
      "By Location",
    ])

    assert_users_menu([
      "API Users",
      "Admin Accounts",
      "Permissions Management",
      "API Scopes",
      "Admin Groups",
    ])

    assert_config_menu([
      "API Backends",
      "Website Backends",
      "Publish Changes",
    ])
  end

  def test_admin_view_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :admin_view_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
      "Users",
    ])

    assert_users_menu([
      "Admin Accounts",
      "Permissions Management",
      "API Scopes",
      "Admin Groups",
    ])
  end

  def test_admin_view_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_admin_manage_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :admin_manage_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_admin_manage_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_analytics_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :analytics_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
      "Analytics",
    ])

    assert_analytics_menu([
      "API Drilldown",
      "Filter Logs",
      "By Users",
      "By Location",
    ])
  end

  def test_analytics_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_backend_manage_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :backend_manage_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
      "Configuration",
    ])

    assert_config_menu([
      "API Backends",
      "Website Backends",
    ])
  end

  def test_backend_manage_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_backend_publish_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :backend_publish_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
      "Configuration",
    ])

    assert_config_menu([
      "Publish Changes",
    ])
  end

  def test_backend_publish_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_user_manage_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :user_manage_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_user_manage_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  def test_user_view_permitted
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :user_view_permission),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
      "Users",
    ])

    assert_users_menu([
      "API Users",
    ])
  end

  def test_user_view_forbidden
    admin = FactoryBot.create(:limited_admin, :groups => [
      FactoryBot.create(:google_admin_group, :permission_ids => []),
    ])
    admin_login(admin)

    assert_nav([
      "API Umbrella",
    ])
  end

  private

  def assert_nav(menus)
    nav = find("nav.navbar")
    assert_equal(menus.join("\n"), nav.text)
  end

  def assert_analytics_menu(items)
    nav = find("nav.navbar")
    menu = nav.find(".nav-analytics .dropdown-menu", :visible => :hidden)
    assert_equal(items.join(" "), menu.text(:all))
  end

  def assert_users_menu(items)
    nav = find("nav.navbar")
    menu = nav.find(".nav-users .dropdown-menu", :visible => :hidden)
    assert_equal(items.join(" "), menu.text(:all))
  end

  def assert_config_menu(items)
    nav = find("nav.navbar")
    menu = nav.find(".nav-config .dropdown-menu", :visible => :hidden)
    assert_equal(items.join(" "), menu.text(:all))
  end
end
