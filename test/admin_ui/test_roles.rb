require_relative "../test_helper"

class Test::AdminUi::TestRoles < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_prefills_user_roles
    FactoryGirl.create(:api_user, :roles => ["test-user-role"])
    admin_login
    visit "/admin/#/api_users/new"
    wait_for_ajax

    find(".selectize-input").click
    assert_text("test-user-role")
  end

  def test_prefills_api_roles
    FactoryGirl.create(:api, :settings => { :required_roles => ["test-api-role"] })
    admin_login
    visit "/admin/#/api_users/new"
    wait_for_ajax

    find(".selectize-input").click
    assert_text("test-api-role")
  end

  def test_refresh_prefilled_options_added_during_current_session
    admin_login
    visit "/admin/#/api_users/new"
    wait_for_ajax

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    find(".selectize-input input").set("test-new-role")
    find(".selectize-dropdown-content div", :text => /Add test-new-role/).click
    click_button("Save")

    assert_text("Successfully saved the user")
    page.execute_script("PNotify.removeAll()")
    refute_text("Successfully saved the user")

    click_link("Add New API User")
    wait_for_ajax
    find(".selectize-input").click
    assert_text("test-new-role")
  end

  def test_share_roles_between_users_and_apis_forms
    admin_login
    visit "/admin/#/api_users/new"
    wait_for_ajax

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    find(".selectize-input input").set("test-new-user-role")
    find(".selectize-dropdown-content div", :text => /Add test-new-user-role/).click
    click_button("Save")

    assert_content("Successfully saved the user")

    visit "/admin/#/apis/new"
    wait_for_ajax

    find("a", :text => /Global Request Settings/).click
    find(".selectize-input").click
    assert_content("test-new-user-role")

    find("a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    find(".modal .selectize-input").click
    assert_content("test-new-user-role")
  end

  private

  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      while(page.evaluate_script("jQuery.active") > 0)
        sleep 0.1
      end
    end
    refute_content(".busy-blocker")
  end
end
