require "securerandom"

module ApiUmbrellaTestHelpers
  module AdminAuth
    def admin_login(admin = nil)
      Capybara.reset_session!
      page.driver.clear_memory_cache
      page.driver.set_cookie("_api_umbrella_session", encrypt_session_cookie(admin_session_data(admin)))

      visit "/admin/login"
      assert_logged_in(admin)
    end

    def csrf_session
      csrf_token = SecureRandom.base64(32)
      session_cookie = encrypt_session_cookie(csrf_session_data(csrf_token))
      { :headers => { "Cookie" => "_api_umbrella_session=#{session_cookie}", "X-CSRF-Token" => csrf_token } }
    end

    def admin_session(admin = nil)
      session_cookie = encrypt_session_cookie(admin_session_data(admin))
      { :headers => { "Cookie" => "_api_umbrella_session=#{session_cookie}" } }
    end

    def admin_csrf_session(admin = nil)
      csrf_token = SecureRandom.base64(32)
      session_cookie = encrypt_session_cookie(admin_session_data.merge(csrf_session_data(csrf_token)))
      { :headers => { "Cookie" => "_api_umbrella_session=#{session_cookie}", "X-CSRF-Token" => csrf_token } }
    end

    def parse_admin_session_cookie(raw_cookie)
      cookie_value = raw_cookie.match(/_api_umbrella_session=([^;\s]+)/)[1]
      cookie_value = CGI.unescape(cookie_value)
      decrypt_session_cookie(cookie_value)
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

    def assert_no_password_fields_on_admin_forms
      admin1 = FactoryGirl.create(:admin)
      admin2 = FactoryGirl.create(:admin)
      admin_login(admin1)

      # Admin cannot edit their own password
      visit "/admin/#/admins/#{admin1.id}/edit"
      assert_content("Edit Admin")
      refute_content("Password")

      # Admins cannot set new admin passwords
      visit "/admin/#/admins/new"
      assert_content("Add Admin")
      refute_content("Password")

      # Admins cannot edit other admin passwords
      visit "/admin/#/admins/#{admin2.id}/edit"
      assert_content("Edit Admin")
      refute_content("Password")
    end

    def assert_password_fields_on_my_account_admin_form_only
      admin1 = FactoryGirl.create(:admin)
      admin2 = FactoryGirl.create(:admin)
      admin_login(admin1)

      # Admin can edit their own password
      visit "/admin/#/admins/#{admin1.id}/edit"
      assert_content("Edit Admin")
      assert_content("Change Your Password")
      assert_field("Current Password")
      assert_field("New Password")
      assert_field("Confirm New Password")

      # Admins cannot set new admin passwords
      visit "/admin/#/admins/new"
      assert_content("Add Admin")
      refute_content("Password")

      # Admins cannot edit other admin passwords
      visit "/admin/#/admins/#{admin2.id}/edit"
      assert_content("Edit Admin")
      refute_content("Password")
    end

    def make_first_time_admin_creation_requests
      get_response = Typhoeus.get("https://127.0.0.1:9081/admins/signup", keyless_http_options)

      create_response = Typhoeus.post("https://127.0.0.1:9081/admins", keyless_http_options.deep_merge(csrf_session).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => {
          :admin => {
            :username => "new@example.com",
            :password => "password123456",
            :password_confirmation => "password123456",
          },
        },
      }))

      [get_response, create_response]
    end

    private

    @@test_rails_secret_token = nil
    def test_rails_secret_token
      unless @@test_rails_secret_token
        test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
        @@test_rails_secret_token = test_config["web"]["rails_secret_token"]
        assert(@@test_rails_secret_token)
      end

      @@test_rails_secret_token
    end

    def csrf_session_data(csrf_token)
      { "_csrf_token" => csrf_token }
    end

    def admin_session_data(admin)
      admin ||= FactoryGirl.create(:admin)
      authenticatable_salt = admin.encrypted_password[0, 29] if(admin.encrypted_password)
      { "warden.user.admin.key" => [[admin.id], authenticatable_salt] }
    end

    def encrypt_session_cookie(data)
      cookies_utils = RailsCompatibleCookiesUtils.new(test_rails_secret_token)
      cookies_utils.encrypt({
        "session_id" => SecureRandom.hex(16),
      }.merge(data))
    end

    def decrypt_session_cookie(cookie_value)
      cookies_utils = RailsCompatibleCookiesUtils.new(test_rails_secret_token)
      cookies_utils.decrypt(cookie_value)
    end
  end
end
