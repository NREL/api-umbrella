require "securerandom"

module ApiUmbrellaTestHelpers
  module AdminUiLogin
    private

    def assert_login_permitted(login_button_text, admin)
      visit "/admin/"
      trigger_click_link(login_button_text)
      assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
    end

    def assert_login_forbidden(login_button_text, error_text)
      visit "/admin/"
      trigger_click_link(login_button_text)
      assert_text(error_text)
      refute_link("my_account_nav_link")
    end

    def mock_userinfo(data)
      # Reset the session and clear caches before setting our cookie. For some
      # reason this seems necessary to ensure click_link always works correctly
      # (otherwise, we sporadically get failures caused by the click_link on the
      # login buttons not actually going anywhere).
      #
      # Possibly related:
      # https://github.com/teampoltergeist/poltergeist/issues/814#issuecomment-248830334
      Capybara.reset_session!
      page.driver.clear_memory_cache

      # Set a cookie to mock the userinfo responses. When the app is running in
      # test mode, it looks for this cookie to provide mock data.
      page.driver.set_cookie("test_mock_userinfo", CGI.escape(Base64.strict_encode64(data)))
      yield
    ensure
      page.driver.remove_cookie("test_mock_userinfo")
    end

    # When using "click_link" on the login buttons we rarely/sporadically see it
    # fail to do anything. Capybara doesn't raise an error, so it thinks it's
    # clicked the button, but nothing appears to happen.
    #
    # As a workaround, find the element and programmatically trigger a click
    # event on it, which seems to be more reliable.
    #
    # See: https://github.com/teampoltergeist/poltergeist/issues/530
    #
    # I think we've only seen this issue in these tests (and not in other parts
    # of the admin app). My theory is that this might be due to the click event
    # firing right as the stylesheets load, so the original location it
    # calculated and then clicks ends up being incorrect once the stylesheets
    # load. I'm not sure about this, but it might explain why it's only happening
    # here, and not within the app (since within the app, all the javascript and
    # stylesheets must be loaded first for there to be anything rendering on the
    # page).
    def trigger_click_link(selector)
      find_link(selector).trigger("click")
    end
  end
end
