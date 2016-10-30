require "securerandom"

module ApiUmbrellaTests
  module AdminAuth
    def admin_login(admin = nil)
      admin ||= FactoryGirl.create(:admin)

      visit "/admins/auth/developer"
      fill_in "Email:", :with => admin.username
      click_button "Sign In"

      # Wait for the page to fully load, including the /admin/auth ajax request
      # which will fill out the "My Account" link. If we don't wait, then
      # navigating to another page immediately may cancel the previous
      # /admin/auth ajax request if it hadn't finished throwing some errors.
      assert_link("my_account_nav_link", :href => /#{admin.id}/, :visible => :all)
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
  end
end
