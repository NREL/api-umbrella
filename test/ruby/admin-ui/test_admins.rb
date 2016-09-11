require "test_helper"

class TestAdminUiAdmins < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_superuser_checkbox_as_superuser_admin
    admin = FactoryGirl.create(:admin)
    visit "/admins/auth/developer"
    fill_in "Email:", :with => admin.username
    click_button "Sign In"

    visit "/admin/#/admins/new"

    assert_content("Username")
    assert_content("Superuser")
  end

  def test_superuser_checkbox_as_limited_admin
    admin = FactoryGirl.create(:limited_admin)
    visit "/admins/auth/developer"
    fill_in "Email:", :with => admin.username
    click_button "Sign In"

    visit "/admin/#/admins/new"

    assert_content("Username")
    refute_content("Superuser")
  end
end
