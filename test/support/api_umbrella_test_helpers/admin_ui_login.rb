require "securerandom"
require "support/api_umbrella_test_helpers/selenium"

module ApiUmbrellaTestHelpers
  module AdminUiLogin
    include ApiUmbrellaTestHelpers::Selenium

    private

    def assert_login_permitted(login_button_text, admin)
      visit "/admin/"
      click_link(login_button_text)
      assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
    end

    def assert_login_forbidden(login_button_text, error_text)
      visit "/admin/"
      click_link(login_button_text)
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
      # Set a cookie to mock the OmniAuth responses. This relies on the
      # TestMockOmniauth middleware we install into the Rails app during the test
      # environment. This gives us a way to mock this data from outside the Rails
      # test suite.
      selenium_add_cookie("test_mock_omniauth", Base64.urlsafe_encode64(MultiJson.dump(omniauth_data)))
      yield
    ensure
      selenium_delete_cookie("test_mock_omniauth")
    end
  end
end
