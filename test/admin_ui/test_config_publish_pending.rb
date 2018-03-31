require_relative "../test_helper"

class Test::AdminUi::TestConfigPublishPending < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    Api.delete_all
    WebsiteBackend.delete_all
    ConfigVersion.delete_all
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_pending_changes_grouped_into_categories
    FactoryBot.create(:api)
    deleted_api = FactoryBot.create(:api)
    modified_api = FactoryBot.create(:api, :name => "Before")
    ConfigVersion.publish!(ConfigVersion.pending_config)
    deleted_api.update(:deleted_at => Time.now.utc)
    modified_api.update(:name => "After")
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    assert_text("1 Deleted API Backends")
    assert_text("1 Modified API Backends")
    assert_text("1 New API Backends")
  end

  def test_hides_categories_without_changes
    ConfigVersion.publish!(ConfigVersion.pending_config)
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    refute_text("Deleted API Backends")
    refute_text("Modified API Backends")
    assert_text("New API Backends")
  end

  def test_message_when_no_changes_to_publish
    FactoryBot.create(:api)
    ConfigVersion.publish!(ConfigVersion.pending_config)

    admin_login
    visit "/admin/#/config/publish"
    assert_text("Published configuration is up to date")
  end

  def test_diff_of_config_changes
    api = FactoryBot.create(:api, :name => "Before")
    ConfigVersion.publish!(ConfigVersion.pending_config)
    api.update(:name => "After")

    admin_login
    visit "/admin/#/config/publish"
    assert_selector(".config-diff", :visible => :hidden)
    click_link("View Config Differences")
    assert_selector(".config-diff", :visible => :visible)
    assert_selector(".config-diff del", :text => "Before")
    assert_selector(".config-diff ins", :text => "After")
  end

  def test_auto_selection_for_single_change
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    assert_selector("input[type=checkbox][name*=publish]", :count => 1)
    assert_selector("input[type=checkbox][name*=publish]:checked", :count => 1)
  end

  def test_no_auto_selection_for_multiple_changes
    FactoryBot.create(:api)
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    assert_selector("input[type=checkbox][name*=publish]", :count => 2)
    refute_selector("input[type=checkbox][name*=publish]:checked")
  end

  def test_refreshes_changes_on_load
    FactoryBot.create(:api)
    ConfigVersion.publish!(ConfigVersion.pending_config)

    admin_login
    visit "/admin/#/config/publish"
    refute_text("New API Backends")

    find("nav a", :text => /Configuration/).click
    find("nav a", :text => /API Backends/).click
    assert_text("Add API Backend")

    FactoryBot.create(:api)
    find("nav a", :text => /Configuration/).click
    find("nav a", :text => /Publish Changes/).click
    assert_text("1 New API Backends")
  end

  def test_check_or_uncheck_all_link
    FactoryBot.create(:api)
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"

    assert_selector("input[type=checkbox][name*=publish]", :count => 2)
    refute_text("Uncheck all")
    assert_text("Check all")
    refute_selector("input[type=checkbox][name*=publish]:checked")

    click_link("Check all")
    assert_selector("input[type=checkbox][name*=publish]:checked")
    refute_text("Check all")
    assert_text("Uncheck all")

    click_link("Uncheck all")
    refute_selector("input[type=checkbox][name*=publish]:checked")
    refute_text("Uncheck all")
    assert_text("Check all")

    checkboxes = all("input[type=checkbox][name*=publish]")
    checkboxes[0].click
    assert_text("Check all")
    checkboxes[1].click
    assert_text("Uncheck all")
    checkboxes[1].click
    assert_text("Check all")
  end

  def test_disables_publish_button_when_no_changes_checked
    FactoryBot.create(:api)
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"

    assert_selector("input[type=checkbox][name*=publish]", :count => 2)
    refute_selector("input[type=checkbox][name*=publish]:checked")
    publish_button = find("#publish_button")
    checkbox = all("input[type=checkbox][name*=publish]")[0]

    assert_equal(false, checkbox[:checked])
    assert_equal(true, publish_button.disabled?)

    checkbox.click
    assert_equal(true, checkbox[:checked])
    assert_equal(false, publish_button.disabled?)

    checkbox.click
    assert_equal(false, checkbox[:checked])
    assert_equal(true, publish_button.disabled?)
  end

  def test_enables_publish_button_on_load_if
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"

    assert_selector("input[type=checkbox][name*=publish]", :count => 1)
    assert_selector("input[type=checkbox][name*=publish]:checked", :count => 1)
    publish_button = find("#publish_button")
    checkbox = all("input[type=checkbox][name*=publish]")[0]

    assert_equal(true, checkbox[:checked])
    assert_equal(false, publish_button.disabled?)

    checkbox.click
    assert_equal(false, checkbox[:checked])
    assert_equal(true, publish_button.disabled?)
  end
end
