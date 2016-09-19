require "test_helper"

class TestAdminUiApiUsersXss < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  def test_xss_escaping_in_table
    @user = FactoryGirl.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users"

    assert_content(@user.email)
    assert_content(@user.first_name)
    assert_content(@user.last_name)
    assert_content(@user.use_description)
    assert_content(@user.registration_source)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_xss_escaping_in_form
    @user = FactoryGirl.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users/#{@user.id}/edit"

    assert_equal(@user.email, find_field("E-mail").value)
    assert_equal(@user.first_name, find_field("First Name").value)
    assert_equal(@user.last_name, find_field("Last Name").value)
    assert_equal(@user.use_description, find_field("Purpose").value)
    assert_content(@user.registration_source)
    refute_selector(".xss-test", :visible => :all)
  end

  def test_xss_escaping_in_flash_confirmation_message
    @user = FactoryGirl.create(:xss_api_user)
    admin_login
    visit "/admin/#/api_users/#{@user.id}/edit"

    fill_in "Last Name", :with => "Doe"
    click_button("Save")

    assert_content("Successfully saved the user \"#{@user.email}\"")
    refute_selector(".xss-test", :visible => :all)
  end
end
