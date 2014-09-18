require 'spec_helper'

describe "admins form", :js => true do
  describe "superuser is logged in" do
    login_admin

    it "shows the superuser checkbox" do
      visit "/admin/#/admins/new"

      page.should have_content("Username")
      page.should have_content("Superuser")
    end
  end

  describe "limited admin is logged in" do
    let(:current_admin) { FactoryGirl.create(:limited_admin) }
    login_admin

    it "hides the superuser checkbox" do
      visit "/admin/#/admins/new"

      page.should have_content("Username")
      page.should_not have_content("Superuser")
    end
  end
end
