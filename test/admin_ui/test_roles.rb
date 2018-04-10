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
    FactoryBot.create(:api_user, :roles => ["test-user-role"])
    admin_login
    visit "/admin/#/api_users/new"
    assert_text("Add API User")

    find(".selectize-input").click
    assert_text("test-user-role")
  end

  def test_prefills_api_roles
    FactoryBot.create(:api, :settings => { :required_roles => ["test-api-role"] })
    admin_login
    visit "/admin/#/api_users/new"
    assert_text("Add API User")

    find(".selectize-input").click
    assert_text("test-api-role")
  end

  def test_refresh_prefilled_options_added_during_current_session
    admin_login
    visit "/admin/#/api_users/new"
    assert_text("Add API User")

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    find(".selectize-input input").set("test-new-role")
    find(".selectize-dropdown-content div", :text => /Add test-new-role/).click
    click_button("Save")

    assert_text("Successfully saved the user")
    page.execute_script("window.PNotifyRemoveAll()")
    refute_text("Successfully saved the user")

    click_link("Add New API User")
    assert_text("Add API User")
    find(".selectize-input").click
    assert_text("test-new-role")
  end

  def test_share_roles_between_users_and_apis_forms
    admin_login
    visit "/admin/#/api_users/new"
    assert_text("Add API User")

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"
    find(".selectize-input input").set("test-new-user-role")
    find(".selectize-dropdown-content div", :text => /Add test-new-user-role/).click
    click_button("Save")

    assert_text("Successfully saved the user")

    visit "/admin/#/apis/new"
    assert_text("Add API")

    find("a", :text => /Global Request Settings/).click
    find(".selectize-input").click
    assert_text("test-new-user-role")

    find("a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    find(".modal .selectize-input").click
    assert_text("test-new-user-role")
  end

  def test_removes_user_roles
    user = FactoryBot.create(:api_user, :roles => ["test-role1", "test-role2"])
    admin_login

    # Remove 1 role
    visit "/admin/#/api_users/#{user.id}/edit"
    assert_text("Edit API User")

    field = find_field("Roles")
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role1×test-role2×")
    find("#" + field["data-selectize-control-id"] + " [data-value=test-role1] .remove").click
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role2×")

    click_button("Save")
    assert_text("Successfully saved")
    page.execute_script("window.PNotifyRemoveAll()")

    user.reload
    assert_equal(user.roles, ["test-role2"])

    # Remove last role
    visit "/admin/#/api_users/#{user.id}/edit"
    assert_text("Edit API User")

    field = find_field("Roles")
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role2×")
    find("#" + field["data-selectize-control-id"] + " [data-value=test-role2] .remove").click
    assert_selector("#" + field["data-selectize-control-id"], :text => "")

    click_button("Save")
    assert_text("Successfully saved")

    user.reload
    assert_nil(user.roles)
  end

  def test_removes_api_roles
    api = FactoryBot.create(:api, :settings => { :required_roles => ["test-role1", "test-role2"] })
    admin_login

    # Remove 1 role
    visit "/admin/#/apis/#{api.id}/edit"
    assert_text("Edit API")

    find("legend a", :text => /Global Request Settings/).click
    field = find_field("Required Roles")
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role1×test-role2×")
    find("#" + field["data-selectize-control-id"] + " [data-value=test-role1] .remove").click
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role2×")

    click_button("Save")
    assert_text("Successfully saved")
    page.execute_script("window.PNotifyRemoveAll()")

    api.reload
    assert_equal(api.settings.required_roles, ["test-role2"])

    # Remove 1 role
    visit "/admin/#/apis/#{api.id}/edit"
    assert_text("Edit API")

    find("legend a", :text => /Global Request Settings/).click
    field = find_field("Required Roles")
    assert_selector("#" + field["data-selectize-control-id"], :text => "test-role2×")
    find("#" + field["data-selectize-control-id"] + " [data-value=test-role2] .remove").click
    assert_selector("#" + field["data-selectize-control-id"], :text => "")

    click_button("Save")
    assert_text("Successfully saved")

    api.reload
    assert_nil(api.settings.required_roles)
  end
end
