require_relative "../../test_helper"

class Test::AdminUi::Login::TestTracking < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_populates_tracking_fields_on_first_login
    admin = FactoryBot.create(:admin)
    assert_nil(admin.current_sign_in_at)
    assert_nil(admin.last_sign_in_at)
    assert_nil(admin.current_sign_in_ip)
    assert_nil(admin.last_sign_in_ip)
    assert_nil(admin.current_sign_in_provider)
    assert_nil(admin.last_sign_in_provider)
    assert_equal(0, admin.sign_in_count)

    visit "/admin/login"
    fill_in "admin_username", :with => admin.username
    fill_in "admin_password", :with => "password123456"
    click_button "sign_in"
    assert_logged_in(admin)

    admin.reload
    assert_kind_of(Time, admin.current_sign_in_at)
    assert_nil(admin.last_sign_in_at)
    assert_kind_of(IPAddr, admin.current_sign_in_ip)
    assert_nil(admin.last_sign_in_ip)
    assert_equal("local", admin.current_sign_in_provider)
    assert_nil(admin.last_sign_in_provider)
    assert_equal(1, admin.sign_in_count)
  end

  def test_shifts_current_values_to_last_values_on_subsequent_logins
    admin = FactoryBot.create(:admin, {
      :current_sign_in_at => Time.iso8601("2017-01-01T01:27:00Z"),
      :last_sign_in_at => Time.iso8601("2017-01-02T01:27:00Z"),
      :current_sign_in_ip => "127.0.0.100",
      :last_sign_in_ip => "127.0.0.200",
      :current_sign_in_provider => "google_oauth2",
      :last_sign_in_provider => "github",
      :sign_in_count => 8,
    })

    visit "/admin/login"
    fill_in "admin_username", :with => admin.username
    fill_in "admin_password", :with => "password123456"
    click_button "sign_in"
    assert_logged_in(admin)

    admin.reload
    assert_kind_of(Time, admin.current_sign_in_at)
    refute_equal(Time.iso8601("2017-01-01T01:27:00Z"), admin.current_sign_in_at)
    assert_equal(Time.iso8601("2017-01-01T01:27:00Z"), admin.last_sign_in_at)
    refute_equal(IPAddr.new("127.0.0.100"), admin.current_sign_in_ip)
    assert_equal(IPAddr.new("127.0.0.100"), admin.last_sign_in_ip)
    assert_equal("local", admin.current_sign_in_provider)
    assert_equal("google_oauth2", admin.last_sign_in_provider)
    assert_equal(9, admin.sign_in_count)
  end
end
