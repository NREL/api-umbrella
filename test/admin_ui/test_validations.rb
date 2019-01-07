require_relative "../test_helper"

class Test::AdminUi::TestValidations < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_client_side_validations
    admin_login
    visit "/admin/#/api_users/new"

    # Messages
    refute_text("Oops")

    # Top messages container
    refute_selector(".alert-danger")
    refute_selector(".error-messages")

    # Inline messages
    refute_selector(".has-error")
    refute_selector(".invalid-feedback")

    # Trigger validations with save of empty form.
    click_button("Save")

    # Messages
    assert_text("Oops")
    assert_text("can't be blank")
    messages = page.all(".error-messages li").map { |msg| msg.text }
    assert_equal([
      "First Name can't be blank",
      "Last Name can't be blank",
      "Email can't be blank",
    ].sort, messages.sort)

    # Top messages container
    assert_selector(".alert-danger")
    assert_selector(".error-messages")

    # Inline messages
    assert_selector(".has-error", :count => 3)
    assert_selector(".invalid-feedback", :count => 3)
  end

  def test_inline_client_side_validations_on_blur
    admin_login
    visit "/admin/#/api_users/new"

    refute_selector(".has-error")
    refute_selector(".invalid-feedback")

    id = find_field("E-mail")[:id]
    page.execute_script("document.getElementById('#{id}').focus(); document.getElementById('#{id}').blur()")

    assert_selector(".has-error", :count => 1)
    assert_selector(".invalid-feedback", :count => 1)
  end

  def test_server_side_validations
    admin_login
    visit "/admin/#/api_users/new"

    # Messages
    refute_text("Oops")
    refute_text("can't be blank")

    # Top messages container
    refute_selector(".alert-danger")
    refute_selector(".error-messages")

    # Inline messages
    refute_selector(".has-error")
    refute_selector(".invalid-feedback")

    # Trigger validations with save of filled out (but invalid) form.
    fill_in "E-mail", :with => "invalid"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    click_button("Save")

    # Messages
    assert_text("Oops")
    messages = page.all(".error-messages li").map { |msg| msg.text }
    assert_equal([
      "Email: Provide a valid email address.",
      "Terms and conditions: Check the box to agree to the terms and conditions.",
    ].sort, messages.sort)

    # Top messages container
    assert_selector(".alert-danger")
    assert_selector(".error-messages")

    # Inline messages
    refute_selector(".has-error")
    refute_selector(".invalid-feedback")
  end

  def test_i18n_client_side
    admin_login
    visit "/admin/#/admins/new"

    click_button("Save")

    assert_text("Oops")
    messages = page.all(".error-messages li").map { |msg| msg.text }
    assert_equal([
      "Email can't be blank",
    ].sort, messages.sort)
  end

  def test_i18n_server_side
    admin_login
    visit "/admin/#/admins/new"

    fill_in "Email", :with => "invalid"
    click_button("Save")

    assert_text("Oops")
    messages = page.all(".error-messages li").map { |msg| msg.text }
    assert_equal([
      "Email: is invalid",
      "Groups: must belong to at least one group or be a superuser",
    ].sort, messages.sort)
  end
end
