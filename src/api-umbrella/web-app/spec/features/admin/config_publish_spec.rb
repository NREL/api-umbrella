require 'spec_helper'

describe "config publish", :js => true do
  login_admin

  before(:each) do
    Api.delete_all
    WebsiteBackend.delete_all
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

    it "selects the api for publishing by default if there is only one pending API" do
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes.length.should eql(1)
      checkboxes.each do |checkbox|
        checkbox[:checked].should eql(true)
      end
    end

    it "selects no apis for publishing by default if there is more than one pending API" do
      FactoryGirl.create(:api)
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes.length.should eql(2)
      checkboxes.each do |checkbox|
        checkbox[:checked].should eql(false)
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

    it "provides a check/uncheck all link" do
      FactoryGirl.create(:api)
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"

      page.should have_content("Check all")
      click_link("Check all")
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes.each do |checkbox|
        checkbox[:checked].should eql(true)
      end

      page.should have_content("Uncheck all")
      click_link("Uncheck all")
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes.each do |checkbox|
        checkbox[:checked].should eql(false)
      end

      page.should have_content("Check all")
      checkboxes = all("input[type=checkbox][name*=publish]")
      checkboxes[0].click
      page.should have_content("Check all")
      checkboxes[1].click
      page.should have_content("Uncheck all")
      checkboxes[1].click
      page.should have_content("Check all")
    end

    it "disables the publish button if no changes are checked for publishing" do
      FactoryGirl.create(:api)
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"

      publish_button = find("#publish_button")
      checkbox = all("input[type=checkbox][name*=publish]")[0]

      checkbox[:checked].should eql(false)
      publish_button.disabled?.should eql(true)

      checkbox.click
      checkbox[:checked].should eql(true)
      publish_button.disabled?.should eql(false)

      checkbox.click
      checkbox[:checked].should eql(false)
      publish_button.disabled?.should eql(true)
    end

    it "enables the publish button on load if the there's a single change pre-checked" do
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"

      publish_button = find("#publish_button")
      checkbox = all("input[type=checkbox][name*=publish]")[0]

      checkbox[:checked].should eql(true)
      publish_button.disabled?.should eql(false)

      checkbox.click
      checkbox[:checked].should eql(false)
      publish_button.disabled?.should eql(true)
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
      FactoryGirl.create(:api)

      visit "/admin/#/config/publish"
      check("config[apis][#{api1.id}][publish]")
      click_button("Publish")

      page.should_not have_content("Published configuration is up to date")
      page.should have_content("1 New API Backends")
      active_config = ConfigVersion.active_config
      active_config["apis"].length.should eql(1)
      active_config["apis"].first["_id"].should eql(api1.id)
    end
  end
end
