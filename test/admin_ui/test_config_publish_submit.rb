require_relative "../test_helper"

class Test::AdminUi::TestConfigPublishSubmit < Minitest::Capybara::Test
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

  def test_publishing_changes
    api = FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    click_button("Publish")
    assert_text("Successfully published the configuration")

    assert_text("Published configuration is up to date")
    active_config = ConfigVersion.active_config
    assert_equal(1, active_config["apis"].length)
    assert_equal(api.id, active_config["apis"].first["_id"])
  end

  def test_publishing_only_selected_changes
    api1 = FactoryBot.create(:api)
    FactoryBot.create(:api)

    admin_login
    visit "/admin/#/config/publish"
    check("config[apis][#{api1.id}][publish]")
    click_button("Publish")

    refute_text("Published configuration is up to date")
    assert_text("1 New API Backends")
    active_config = ConfigVersion.active_config
    assert_equal(1, active_config["apis"].length)
    assert_equal(api1.id, active_config["apis"].first["_id"])
  end
end
