require_relative "../test_helper"

class Test::AdminUi::TestVersionDisplay < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    FactoryBot.create(:admin)
    @expected_version = File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip
  end

  def test_rails_login_page_no_version
    visit "/admin/"
    assert_text("Admin Sign In")
    refute_text("API Umbrella Version")
    refute_text(@expected_version)
  end

  def test_version_in_ember_pages
    admin_login
    assert_text("Analytics")
    assert_text("API Umbrella Version #{@expected_version}")
  end
end
