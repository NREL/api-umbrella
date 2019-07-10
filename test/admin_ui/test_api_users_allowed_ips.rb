require_relative "../test_helper"

class Test::AdminUi::TestApiUsersAllowedIps < Minitest::Capybara::Test
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
    assert_nil(user.settings.allowed_ips)
  end

  def test_multiple_lines_saves_as_array
    admin_login
    visit "/admin/#/api_users/new"

    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    label_check "User agrees to the terms and conditions"
    fill_in "Restrict Access to IPs", :with => "10.0.0.0/8\n\n\n\n127.0.0.1"
    click_button("Save")

    assert_text("Successfully saved the user")
    user = ApiUser.order(:created_at => :asc).last
    assert_equal([IPAddr.new("10.0.0.0/8"), IPAddr.new("127.0.0.1")], user.settings.allowed_ips)
  end

  def test_displays_existing_array_as_multiple_lines
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_ips => ["10.0.0.0/24", "10.2.2.2"],
      }),
    })
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    assert_equal("10.0.0.0/24\n10.2.2.2", find_field("Restrict Access to IPs").value)
  end

  def test_nullifies_existing_array_when_empty_input_saved
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_ips => ["10.0.0.0/24", "10.2.2.2"],
      }),
    })
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    assert_equal("10.0.0.0/24\n10.2.2.2", find_field("Restrict Access to IPs").value)
    fill_in "Restrict Access to IPs", :with => "", :fill_options => { :clear => :backspace }
    click_button("Save")

    assert_text("Successfully saved the user")
    user.reload
    assert_nil(user.settings.allowed_ips)
  end
end
