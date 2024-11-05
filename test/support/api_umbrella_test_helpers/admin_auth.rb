require "securerandom"
require "support/api_umbrella_test_helpers/selenium"

module ApiUmbrellaTestHelpers
  module AdminAuth
    # Since lua-resty-session checks the user agent when decrypting the session
    # (to ensure the session hasn't been lifted and being used elsewhere), set
    # a hard-coded user agent when we're pre-seeding the session cookie value.
    STATIC_USER_AGENT = "TestStaticUserAgent".freeze

    include ApiUmbrellaTestHelpers::Selenium

    def admin_login(admin = nil)
      selenium_add_cookie("_api_umbrella_session", encrypt_session_cookie(admin_session_data(admin)))

      visit "/admin/login"
      assert_logged_in(admin)
    end

    def csrf_session
      csrf_token_key = SecureRandom.hex(20)
      session_client_cookie = encrypt_session_client_cookie(csrf_session_data(csrf_token_key))
      {
        :headers => {
          "Cookie" => "_api_umbrella_session_client=#{session_client_cookie}",
          "User-Agent" => STATIC_USER_AGENT,
          "X-CSRF-Token" => csrf_token(csrf_token_key),
        },
      }
    end

    def admin_session(admin = nil)
      session_cookie = encrypt_session_cookie(admin_session_data(admin))
      {
        :headers => {
          "Cookie" => "_api_umbrella_session=#{session_cookie}",
          "User-Agent" => STATIC_USER_AGENT,
        },
      }
    end

    def admin_csrf_session(admin = nil)
      csrf_token_key = SecureRandom.hex(20)
      session_cookie = encrypt_session_cookie(admin_session_data(admin))
      session_client_cookie = encrypt_session_client_cookie(csrf_session_data(csrf_token_key))
      {
        :headers => {
          "Cookie" => "_api_umbrella_session=#{session_cookie}; _api_umbrella_session_client=#{session_client_cookie}",
          "User-Agent" => STATIC_USER_AGENT,
          "X-CSRF-Token" => csrf_token(csrf_token_key),
        },
      }
    end

    def parse_admin_session_cookie(raw_cookies)
      cookie_value = Array(raw_cookies).join("; ").match(/_api_umbrella_session=([^;\s]+)/)[1]
      cookie_value = CGI.unescape(cookie_value)
      decrypt_session_cookie(cookie_value)
    end

    def parse_admin_session_client_cookie(raw_cookies)
      cookie_value = Array(raw_cookies).join("; ").match(/_api_umbrella_session_client=([^;\s]+)/)[1]
      cookie_value = CGI.unescape(cookie_value)
      decrypt_session_client_cookie(cookie_value)
    end

    def admin_token(admin = nil)
      admin ||= FactoryBot.create(:admin)
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

      assert_equal("https://127.0.0.1:9081/admin/", get_response.headers["Location"])
      assert_equal("https://127.0.0.1:9081/admin/", create_response.headers["Location"])

      assert_equal(initial_count, Admin.count)
    end

    def assert_first_time_admin_creation_not_found
      initial_count = Admin.count

      get_response, create_response = make_first_time_admin_creation_requests
      assert_response_code(404, get_response)
      assert_response_code(404, create_response)

      assert_equal(initial_count, Admin.count)
    end

    def assert_no_password_fields_on_admin_forms
      admin1 = FactoryBot.create(:admin)
      admin2 = FactoryBot.create(:admin)
      admin_login(admin1)

      # Admin cannot edit their own password
      visit "/admin/#/admins/#{admin1.id}/edit"
      assert_text("Edit Admin")
      assert_field("Email", :with => admin1.username)
      refute_text("Password")

      # Admins cannot edit other admin passwords
      visit "/admin/#/admins/#{admin2.id}/edit"
      assert_text("Edit Admin")
      assert_field("Email", :with => admin2.username)
      refute_text("Password")

      # Admins cannot set new admin passwords
      visit "/admin/#/admins/new"
      assert_text("Add Admin")
      refute_text("Password")
    end

    def assert_password_fields_on_my_account_admin_form_only
      admin1 = FactoryBot.create(:admin)
      admin2 = FactoryBot.create(:admin)
      admin_login(admin1)

      # Admin can edit their own password
      visit "/admin/#/admins/#{admin1.id}/edit"
      assert_text("Edit Admin")
      assert_field("Email", :with => admin1.username)
      assert_text("Change Your Password")
      assert_field("Current Password")
      assert_field("New Password")
      assert_field("Confirm New Password")
      assert_text("14 characters minimum")

      # Admins cannot edit other admin passwords
      visit "/admin/#/admins/#{admin2.id}/edit"
      assert_text("Edit Admin")
      assert_field("Email", :with => admin2.username)
      refute_text("Password")

      # Admins cannot set new admin passwords
      visit "/admin/#/admins/new"
      assert_text("Add Admin")
      refute_text("Password")
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

    def assert_current_admin_url(fragment_path, fragment_query_values)
      uri = Addressable::URI.parse(page.current_url)
      assert_equal("/admin/", uri.path)
      assert(uri.fragment)

      fragment_uri = Addressable::URI.parse(uri.fragment)
      assert_equal(fragment_path, fragment_uri.path)
      if(fragment_query_values.nil?)
        assert_nil(fragment_uri.query_values)
      else
        assert_equal(fragment_query_values, fragment_uri.query_values)
      end
    end

    private

    def csrf_session_data(csrf_token_key)
      { "csrf_token_key" => csrf_token_key }
    end

    def csrf_token(csrf_token_key)
      iv = SecureRandom.hex(6)
      data_encrypted = Encryptor.encrypt({
        :value => csrf_token_key,
        :iv => iv,
        :key => Digest::SHA256.digest($config["secret_key"]),
        :auth_data => [
          STATIC_USER_AGENT,
          "http",
        ].join(""),
      })

      "#{Base64.strict_encode64(data_encrypted)}|#{iv}"
    end

    def admin_session_data(admin)
      admin ||= FactoryBot.create(:admin)
      { "admin_id" => admin.id }
    end

    def session_base64_encode(value)
      Base64.urlsafe_encode64(value, padding: false)
    end

    def session_base64_decode(value)
      Base64.urlsafe_decode64(value)
    end

    def encrypt_session_cookie(data)
      id = SecureRandom.hex(20)
      id_encoded = session_base64_encode(id)
      iv = id[0, 12]
      expires = Time.now.to_i + 3600
      audience = "default"
      data_serialized = MultiJson.dump([[data, audience]])
      hmac_data_key = OpenSSL::HMAC.digest("sha256", $config["secret_key"], [
        id,
        expires,
      ].join(""))
      hmac_data = OpenSSL::HMAC.digest("sha256", hmac_data_key, [
        id,
        expires,
        data_serialized,
        STATIC_USER_AGENT,
        "http",
      ].join(""))
      auth_data = [
        STATIC_USER_AGENT,
        "http",
      ].join("")

      data_encrypted = Encryptor.encrypt({
        :value => data_serialized,
        :iv => iv,
        :key => Digest::SHA256.digest($config["secret_key"]),
        :auth_data => auth_data,
      })

      Session.create!({
        :id_hash => id_encoded,
        :expires_at => Time.at(expires).utc,
        :data_encrypted => data_encrypted,
        :data_encrypted_iv => iv,
      })

      [
        id_encoded,
        expires,
        session_base64_encode(hmac_data),
      ].join("|")
    end

    def decrypt_session_cookie(cookie_value)
      parts = cookie_value.split("|")
      id_encoded = parts[0]
      auth_data = [
        STATIC_USER_AGENT,
        "http",
      ].join("")

      session = Session.find_by(:id_hash => id_encoded)

      data_serialized = Encryptor.decrypt({
        :value => session.data_encrypted,
        :iv => session.data_encrypted_iv,
        :key => Digest::SHA256.digest($config["secret_key"]),
        :auth_data => auth_data,
      })

      MultiJson.load(data_serialized)
    end

    # Serialize an encrypted cookie using the lua-resty-session v4 spec:
    # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L72-L95
    def encrypt_lua_resty_session_cookie(data)
      # Assemble the beginning part of the header data:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L926-L933
      ikm = Digest::SHA256.digest($config.fetch("secret_key"))
      cookie_type = 1
      flags = 0
      sid = SecureRandom.bytes(32)
      creation_time = Time.now.to_i
      rolling_offset = 0
      data_size = Base64.urlsafe_encode64(data, padding: false).length
      idling_offset = 0

      # Pack the values as binary according to:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session/utils.lua#L52-L76
      cookie_header = [
        [cookie_type].pack("C").ljust(1, "\x00")[0, 1],
        [flags].pack("S<").ljust(1, "\x00")[0, 2],
        sid,
        [creation_time].pack("L<").ljust(5, "\x00")[0, 5],
        [rolling_offset].pack("I<").ljust(4, "\x00")[0, 4],
        [data_size].pack("I<").ljust(3, "\x00")[0, 3],
      ].join("")

      # Determine the encryption key and IV from the `sid`:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L936-L941
      sid_key = OpenSSL::KDF.hkdf(ikm, salt: "", info: "encryption:#{sid}", length: 44, hash: "SHA256")
      aes_key = sid_key[0, 32]
      iv = sid_key[32, 12]

      # Encrypt the cookie data, using the header as auth data:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L947-L950
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      cipher.key = aes_key
      cipher.iv = iv
      cipher.auth_data = cookie_header
      ciphertext = cipher.update(data)
      ciphertext << cipher.final
      tag = cipher.auth_tag

      # Append the encryption tag and other pieces to the header:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L952
      cookie_header += [
        tag,
        [idling_offset].pack("I<").ljust(3, "\x00")[0, 3],
      ].join("")

      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L954-L959
      mac_key = OpenSSL::KDF.hkdf(ikm, salt: "", info: "authentication:#{sid}", length: 32, hash: "SHA256")
      mac = OpenSSL::HMAC.digest("sha256", mac_key, cookie_header)[0, 16]
      cookie_header += mac

      # Assemble the header and encrypted value together:
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L960-L968
      # https://github.com/bungle/lua-resty-session/blob/v4.0.5/lib/resty/session.lua#L998-L1003
      session_base64_encode(cookie_header) + session_base64_encode(ciphertext)

    end

    def encrypt_session_client_cookie(data)
      audience = "default"
      data_serialized = MultiJson.dump([[data, audience]])
      encrypt_lua_resty_session_cookie(data_serialized)
    end

    def decrypt_session_client_cookie(cookie_value)
      parts = cookie_value.split("|")
      id_encoded = parts[0]
      id = session_base64_decode(id_encoded)
      iv = id[0, 12]
      data = session_base64_decode(parts[2])
      auth_data = [
        STATIC_USER_AGENT,
        "http",
      ].join("")

      data_serialized = Encryptor.decrypt({
        :value => data,
        :iv => iv,
        :key => Digest::SHA256.digest($config["secret_key"]),
        :auth_data => auth_data,
      })

      MultiJson.load(data_serialized)
    end
  end
end
