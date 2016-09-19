require "securerandom"

module ApiUmbrellaTests
  module AdminAuth
    def admin_login(admin = nil)
      admin ||= FactoryGirl.create(:admin)

      visit "/admins/auth/developer"
      fill_in "Email:", :with => admin.username
      click_button "Sign In"
    end
  end
end
