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

    def omniauth_base_data(options)
      omniauth_base_data = LazyHash.build_hash
      omniauth_base_data["provider"] = options.fetch(:provider).to_s
      if(options[:verified_path])
        LazyHash.add(omniauth_base_data, options.fetch(:verified_path), true)
      end

      if(options[:extra])
        omniauth_base_data.deep_merge!(options[:extra])
      end

      omniauth_base_data
    end

    def mock_omniauth(omniauth_data)
      # Reset the session and clear caches before setting our cookie. For some
      # reason this seems necessary to ensure click_link always works correctly
      # (otherwise, we sporadically get failures caused by the click_link on the
      # login buttons not actually going anywhere).
      #
      # Possibly related:
      # https://github.com/teampoltergeist/poltergeist/issues/814#issuecomment-248830334
      Capybara.reset_session!
      page.driver.clear_memory_cache

      # Set a cookie to mock the OmniAuth responses. This relies on the
      # TestMockOmniauth middleware we install into the Rails app during the test
      # environment. This gives us a way to mock this data from outside the Rails
      # test suite.
      page.driver.set_cookie("test_mock_omniauth", Base64.urlsafe_encode64(MultiJson.dump(omniauth_data)))
      yield
    ensure
      page.driver.remove_cookie("test_mock_omniauth")
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
