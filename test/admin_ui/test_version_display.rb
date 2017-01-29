require_relative "../test_helper"

class Test::AdminUi::TestVersionDisplay < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    @expected_version = File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip
  end

  def test_rails_login_page_no_version
    visit "/admin/"
    assert_content("Admin Sign In")
    refute_content("API Umbrella Version")
    refute_content(@expected_version)
  end

  def test_version_in_ember_pages
    admin_login
    assert_content("Analytics")
    assert_content("API Umbrella Version #{@expected_version}")
  end
end
