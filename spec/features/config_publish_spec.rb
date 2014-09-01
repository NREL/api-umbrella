require 'spec_helper'

describe "config publish", :js => true do
  before(:each) do
    Api.delete_all
    ConfigVersion.delete_all
  end

  describe "preview config changes" do
    it "shows the pending configuration changes grouped into categories" do
      identical_api = FactoryGirl.create(:api)
      deleted_api = FactoryGirl.create(:api)
      modified_api = FactoryGirl.create(:api, :name => "Before")
      ConfigVersion.publish!(ConfigVersion.pending_config)
      deleted_api.destroy
      modified_api.update_attribute(:name, "After")
      new_api = FactoryGirl.create(:api)

      visit "/admins/auth/developer"
      fill_in "Email", :with => "admin"
      click_button "Sign In"

      visit "/admin/#/config/publish"
      page.should have_content("1 Deleted API Backends")
      page.should have_content("1 Modified API Backends")
      page.should have_content("1 New API Backends")
    end

    it "hides the categories that have no changes" do
      ConfigVersion.publish!(ConfigVersion.pending_config)
      new_api = FactoryGirl.create(:api)

      visit "/admins/auth/developer"
      fill_in "Email", :with => "admin"
      click_button "Sign In"

      visit "/admin/#/config/publish"
      page.should_not have_content("Deleted API Backends")
      page.should_not have_content("Modified API Backends")
      page.should have_content("New API Backends")
    end

    it "presents a message when there are no configuration changes to publish" do
      api = FactoryGirl.create(:api)
      ConfigVersion.publish!(ConfigVersion.pending_config)

      visit "/admins/auth/developer"
      fill_in "Email", :with => "admin"
      click_button "Sign In"

      visit "/admin/#/config/publish"
      page.should have_content("Published configuration is up to date")
    end

    it "shows a diff view of the configuration" do
      api = FactoryGirl.create(:api, :name => "Before")
      ConfigVersion.publish!(ConfigVersion.pending_config)
      api.update_attribute(:name, "After")

      visit "/admins/auth/developer"
      fill_in "Email", :with => "admin"
      click_button "Sign In"

      visit "/admin/#/config/publish"
      find(".config-diff", :visible => false).visible?.should eql(false)
      click_link("View Config Differences")
      find(".config-diff").visible?.should eql(true)
      find(".config-diff del").text.should eql("Before")
      find(".config-diff ins").text.should eql("After")
    end
  end
end
