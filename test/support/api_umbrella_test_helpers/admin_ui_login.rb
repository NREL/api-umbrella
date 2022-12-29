require "securerandom"
require "support/api_umbrella_test_helpers/selenium"

module ApiUmbrellaTestHelpers
  module AdminUiLogin
    include ApiUmbrellaTestHelpers::Selenium

    private

    def assert_login_permitted(login_button_text, admin)
      visit "/admin/"
      click_button(login_button_text)
      assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
    end

    def assert_login_forbidden(login_button_text, error_text)
      visit "/admin/"
      click_button(login_button_text)
      assert_text(error_text)
      refute_link("my_account_nav_link")
    end

    def mock_userinfo(data)
      # Set a cookie to mock the userinfo responses. When the app is running in
      # test mode, it looks for this cookie to provide mock data.
      selenium_add_cookie("test_mock_userinfo", CGI.escape(Base64.strict_encode64(data)))
      yield
    ensure
      selenium_delete_cookie("test_mock_userinfo")
    end
  end
end
