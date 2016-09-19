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
      assert_link("My Account", :href => /#{admin.id}/, :visible => :all)
    end
  end
end
