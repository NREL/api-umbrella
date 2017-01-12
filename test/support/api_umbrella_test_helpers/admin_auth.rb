require "securerandom"

module ApiUmbrellaTestHelpers
  module AdminAuth
    def admin_login(admin = nil)
      admin ||= FactoryGirl.create(:admin, :encrypted_password => BCrypt::Password.create("password"))

      visit "/admin/login"
      fill_in "admin_username", :with => admin.username
      fill_in "admin_password", :with => "password"
      click_button "sign_in"
      assert_logged_in(admin)
    end

    def csrf_session
      csrf_token = SecureRandom.base64(32)

      cookies_utils = RailsCompatibleCookiesUtils.new("aeec385fb48a0594b6bb0b18f62473190f1d01b0b6113766af525be2ae1a317a03ab0ee1b3ee6aca3fb1572dc87684e033dcec21acd90d0ca0f111ca1785d0e9")
      session = cookies_utils.encrypt({
        "session_id" => SecureRandom.hex(16),
        "_csrf_token" => csrf_token,
      })

      { :headers => { "Cookie" => "_api_umbrella_session=#{session}", "X-CSRF-Token" => csrf_token } }
    end

    def admin_session(admin = nil)
      admin ||= FactoryGirl.create(:admin)
      cookies_utils = RailsCompatibleCookiesUtils.new("aeec385fb48a0594b6bb0b18f62473190f1d01b0b6113766af525be2ae1a317a03ab0ee1b3ee6aca3fb1572dc87684e033dcec21acd90d0ca0f111ca1785d0e9")
      session = cookies_utils.encrypt({
        "session_id" => SecureRandom.hex(16),
        "warden.user.admin.key" => [[admin.id], nil],
      })

      { :headers => { "Cookie" => "_api_umbrella_session=#{session}" } }
    end

    def admin_token(admin = nil)
      admin ||= FactoryGirl.create(:admin)
      { :headers => { "X-Admin-Auth-Token" => admin.authentication_token } }
    end

    def assert_logged_in(admin = nil)
      # Wait for the page to fully load, including the /admin/auth ajax request
      # which will fill out the "My Account" link. If we don't wait, then
      # navigating to another page immediately may cancel the previous
      # /admin/auth ajax request if it hadn't finished throwing some errors.
      if(admin)
        assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
      else
        assert_link("my_account_nav_link", :visible => :all)
      end
    end

    def assert_first_time_admin_creation_allowed
      assert_equal(0, Admin.count)

      get_response, create_response = make_first_time_admin_creation_requests
      assert_response_code(200, get_response)
      assert_response_code(302, create_response)

      assert_equal("https://127.0.0.1:9081/admin/#/login", create_response.headers["Location"])

      assert_equal(1, Admin.count)
    end

    def assert_first_time_admin_creation_forbidden
      initial_count = Admin.count

      get_response, create_response = make_first_time_admin_creation_requests
      assert_response_code(302, get_response)
      assert_response_code(302, create_response)

      assert_equal("https://127.0.0.1:9081/admin", get_response.headers["Location"])
      assert_equal("https://127.0.0.1:9081/admin", create_response.headers["Location"])

      assert_equal(initial_count, Admin.count)
    end

    def make_first_time_admin_creation_requests
      get_response = Typhoeus.get("https://127.0.0.1:9081/admins/signup", keyless_http_options)

      create_response = Typhoeus.post("https://127.0.0.1:9081/admins", keyless_http_options.deep_merge(csrf_session).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => {
          :admin => {
            :username => "new@example.com",
            :password => "password",
            :password_confirmation => "password",
          },
        },
      }))

      [get_response, create_response]
    end
  end
end
