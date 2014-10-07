require 'spec_helper'

describe "roles", :js => true do
  login_admin

  before(:each) do
    ApiUser.where(:registration_source.ne => "seed").delete_all
    Api.delete_all
  end

  describe "selectize options" do
    it "prefills available options based on existing user roles" do
      FactoryGirl.create(:api_user, :roles => ["test-user-role"])

      visit "/admin/#/api_users/new"
      find(".selectize-input").click
      page.should have_content("test-user-role")
    end

    it "prefills available options based on existing api roles" do
      FactoryGirl.create(:api, :settings => { :required_roles => ["test-api-role"] })

      visit "/admin/#/api_users/new"
      find(".selectize-input").click
      page.should have_content("test-api-role")
    end

    it "refreshes prefill options with newly added roles during the current session" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      find(".selectize-input input").set("test-new-role")
      find(".selectize-dropdown-content div", :text => /Add test-new-role/).click
      click_button("Save")

      page.should have_content("Successfully saved the user")

      click_link("Add New API User")
      find(".selectize-input").click
      page.should have_content("test-new-role")
    end

    it "refreshes prefill options when roles are removed during the current session" do
      user = FactoryGirl.create(:api_user, :roles => ["test-delete-role"])

      visit "/admin/#/api_users/#{user.id}/edit"
      find(".selectize-input div[data-value='test-delete-role'] a.remove").click
      click_button("Save")

      page.should have_content("Successfully saved the user")

      click_link("Add New API User")
      find(".selectize-input").click
      page.should_not have_content("test-delete-role")
    end

    it "shares role options between the api user form and the api backend forms" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      find(".selectize-input input").set("test-new-user-role")
      find(".selectize-dropdown-content div", :text => /Add test-new-user-role/).click
      click_button("Save")

      page.should have_content("Successfully saved the user")

      visit "/admin/#/apis/new"

      find("a", :text => /Global Request Settings/).click
      find(".selectize-input").click
      page.should have_content("test-new-user-role")

      find("a", :text => /Sub-URL Request Settings/).click
      find("button", :text => /Add URL Settings/).click
      sleep 2
      find(".modal .selectize-input").click
      page.should have_content("test-new-user-role")
    end
  end
end
