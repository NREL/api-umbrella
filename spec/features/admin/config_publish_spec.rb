require 'spec_helper'

describe "config publish", :js => true do
  login_admin

  before(:each) do
    Api.delete_all
    ConfigVersion.delete_all
  end

  describe "review config changes" do
    it "shows the pending configuration changes grouped into categories" do
      FactoryGirl.create(:api)
      deleted_api = FactoryGirl.create(:api)
      modified_api = FactoryGirl.create(:api, :name => "Before")
      ConfigVersion.publish!(ConfigVersion.pending_config)
      deleted_api.destroy
      modified_api.update_attribute(:name, "After")
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      page.should have_content("1 Deleted API Backends")
      page.should have_content("1 Modified API Backends")
      page.should have_content("1 New API Backends")
    end

    it "hides the categories that have no changes" do
      ConfigVersion.publish!(ConfigVersion.pending_config)
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      page.should_not have_content("Deleted API Backends")
      page.should_not have_content("Modified API Backends")
      page.should have_content("New API Backends")
    end

    it "presents a message when there are no configuration changes to publish" do
      FactoryGirl.create(:api)
      ConfigVersion.publish!(ConfigVersion.pending_config)

      visit "/admin/#/config/publish"
      page.should have_content("Published configuration is up to date")
    end

    it "shows a diff view of the configuration" do
      api = FactoryGirl.create(:api, :name => "Before")
      ConfigVersion.publish!(ConfigVersion.pending_config)
      api.update_attribute(:name, "After")

      visit "/admin/#/config/publish"
      find(".config-diff", :visible => false).visible?.should eql(false)
      click_link("View Config Differences")
      find(".config-diff").visible?.should eql(true)
      find(".config-diff del").text.should eql("Before")
      find(".config-diff ins").text.should eql("After")
    end

    it "selects all apis for publishing by default" do
      FactoryGirl.create(:api)
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes.length.should eql(2)
      checkboxes.each do |checkbox|
        checkbox[:checked].should eql(true)
      end
    end

    it "refreshes the display when navigated away and back to" do
      FactoryGirl.create(:api)
      ConfigVersion.publish!(ConfigVersion.pending_config)

      visit "/admin/#/config/publish"
      page.should_not have_content("New API Backends")

      visit "/admin/#/apis"

      FactoryGirl.create(:api)
      visit "/admin/#/config/publish"
      page.should have_content("1 New API Backends")
    end
  end

  describe "publish config changes" do
    it "publishes the changes" do
      api = FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      click_button("Publish")

      page.should have_content("Published configuration is up to date")
      active_config = ConfigVersion.active_config
      active_config["apis"].length.should eql(1)
      active_config["apis"].first["_id"].should eql(api.id)
    end

    it "displays a notification after successfully publishing" do
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      click_button("Publish")

      page.should have_content("Successfully published the configuration")
    end

    it "publishes only the selected changes" do
      api1 = FactoryGirl.create(:api)
      api2 = FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      uncheck("config[apis][#{api1.id}][publish]")
      click_button("Publish")

      page.should_not have_content("Published configuration is up to date")
      page.should have_content("1 New API Backends")
      active_config = ConfigVersion.active_config
      active_config["apis"].length.should eql(1)
      active_config["apis"].first["_id"].should eql(api2.id)
    end
  end
end
