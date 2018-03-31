require_relative "../test_helper"

class Test::AdminUi::TestApiUsersXss < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_xss_escaping_in_table
    @user = FactoryBot.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users"

    assert_text(@user.email)
    assert_text(@user.first_name)
    assert_text(@user.last_name)
    assert_text(@user.use_description)
    assert_text(@user.registration_source)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_xss_escaping_in_form
    @user = FactoryBot.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users/#{@user.id}/edit"

    assert_equal(@user.email, find_field("E-mail").value)
    assert_equal(@user.first_name, find_field("First Name").value)
    assert_equal(@user.last_name, find_field("Last Name").value)
    assert_equal(@user.use_description, find_field("Purpose").value)
    assert_text(@user.registration_source)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_xss_escaping_in_flash_confirmation_message
    @user = FactoryBot.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users/#{@user.id}/edit"

    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    click_button("Save")

    assert_text("Successfully saved the user \"#{@user.email}\"")
    refute_selector(".xss-test", :visible => :all)
  end
end
