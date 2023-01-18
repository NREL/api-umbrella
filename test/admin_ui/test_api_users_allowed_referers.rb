require_relative "../test_helper"

class Test::AdminUi::TestApiUsersAllowedReferers < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_empty_input_saves_as_null
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    click_button("Save")

    assert_text("Successfully saved the user")
    user = ApiUser.order(:created_at => :asc).last
    assert_nil(user.settings.allowed_referers)
  end

  def test_multiple_lines_saves_as_array
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    fill_in "Restrict Access to HTTP Referers", :with => "*.example.com/*\n\n\n\nhttp://google.com/*"
    click_button("Save")

    assert_text("Successfully saved the user")
    user = ApiUser.order(:created_at => :asc).last
    assert_equal(["*.example.com/*", "http://google.com/*"], user.settings.allowed_referers)
  end

  def test_displays_existing_array_as_multiple_lines
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_referers => ["*.example.com/*", "http://google.com/*"],
      }),
    })
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    assert_equal("*.example.com/*\nhttp://google.com/*", find_field("Restrict Access to HTTP Referers").value)
  end

  def test_nullifies_existing_array_when_empty_input_saved
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_referers => ["*.example.com/*", "http://google.com/*"],
      }),
    })
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    assert_equal("*.example.com/*\nhttp://google.com/*", find_field("Restrict Access to HTTP Referers").value)
    fill_in "Restrict Access to HTTP Referers", :with => "", :fill_options => { :clear => :backspace }
    click_button("Save")

    assert_text("Successfully saved the user")
    user.reload
    assert_nil(user.settings.allowed_referers)
  end
end
