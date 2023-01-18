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
    FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:api_backend_settings, {
        :required_roles => ["test-api-role"],
      }),
    })
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

    fill_in "E-mail", :with => "#{unique_test_id}@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    selectize_add "Roles", "test-new-role"
    click_button("Save")

    assert_text("Successfully saved the user")
    page.execute_script("window.PNotifyRemoveAll()")
    refute_text("Successfully saved the user")

    user = ApiUser.find_by!(:email => "#{unique_test_id}@example.com")
    assert_equal(["test-new-role"], user.roles)

    click_link("Add New API User")
    assert_text("Add API User")
    find(".selectize-input").click
    assert_text("test-new-role")
  end

  def test_share_roles_between_users_and_apis_forms
    admin_login
    visit "/admin/#/api_users/new"
    assert_text("Add API User")

    fill_in "E-mail", :with => "#{unique_test_id}@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    selectize_add "Roles", "test-new-user-role"
    click_button("Save")

    assert_text("Successfully saved the user")

    user = ApiUser.find_by!(:email => "#{unique_test_id}@example.com")
    assert_equal(["test-new-user-role"], user.roles)

    visit "/admin/#/apis/new"
    assert_text("Add API")

    find("legend button", :text => /Global Request Settings/).click
    find(".selectize-input").click
    assert_text("test-new-user-role")

    find("legend button", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    find(".modal-content .selectize-input").click
    assert_text("test-new-user-role")
  end

  def test_removes_user_roles
    user = FactoryBot.create(:api_user, :roles => ["test-role1", "test-role2"])
    admin_login

    # Remove 1 role
    visit "/admin/#/api_users/#{user.id}/edit"
    assert_text("Edit API User")

    assert_selectize_field("Roles", :with => "test-role1,test-role2")
    selectize_remove "Roles", "test-role1"
    assert_selectize_field("Roles", :with => "test-role2")

    click_button("Save")
    assert_text("Successfully saved")
    page.execute_script("window.PNotifyRemoveAll()")

    user.reload
    assert_equal(user.roles, ["test-role2"])

    # Remove last role
    visit "/admin/#/api_users/#{user.id}/edit"
    assert_text("Edit API User")

    assert_selectize_field("Roles", :with => "test-role2")
    selectize_remove "Roles", "test-role2"
    assert_selectize_field("Roles", :with => "")

    click_button("Save")
    assert_text("Successfully saved")

    user.reload
    assert_equal([], user.roles)
  end

  def test_removes_api_roles
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:api_backend_settings, {
        :required_roles => ["test-role1", "test-role2"],
      }),
    })
    admin_login

    # Remove 1 role
    visit "/admin/#/apis/#{api.id}/edit"
    assert_text("Edit API")

    find("legend button", :text => /Global Request Settings/).click
    assert_selectize_field("Required Roles", :with => "test-role1,test-role2")
    selectize_remove "Required Roles", "test-role1"
    assert_selectize_field("Required Roles", :with => "test-role2")

    click_button("Save")
    assert_text("Successfully saved")
    page.execute_script("window.PNotifyRemoveAll()")

    api.reload
    assert_equal(api.settings.required_roles, ["test-role2"])

    # Remove 1 role
    visit "/admin/#/apis/#{api.id}/edit"
    assert_text("Edit API")

    find("legend button", :text => /Global Request Settings/).click
    assert_selectize_field("Required Roles", :with => "test-role2")
    selectize_remove "Required Roles", "test-role2"
    assert_selectize_field("Required Roles", :with => "")

    click_button("Save")
    assert_text("Successfully saved")

    api.reload
    assert_equal([], api.settings.required_roles)
  end
end
