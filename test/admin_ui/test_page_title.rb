require_relative "../test_helper"

class Test::AdminUi::TestPageTitle < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_rails_login_page_title
    visit "/admin/"
    assert_content("Admin Login")
    assert_equal("API Umbrella Admin", page.title)
  end

  def test_ember_page_title
    admin_login
    assert_content("Analytics")
    assert_equal("API Umbrella Admin", page.title)
  end
end
