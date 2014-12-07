require 'spec_helper'

describe "api users form", :js => true do
  login_admin

  describe "api key in the save notification" do
    it "shows the api key when creating a new account" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.last_name.should eql("Doe")
      page.should have_content(user.api_key)
    end

    it "shows the api key when editing a recently created account" do
      user = FactoryGirl.create(:api_user, :created_by => @current_admin.id)
      visit "/admin/#/api_users/#{user.id}/edit"

      fill_in "Last Name", :with => "Updated"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.last_name.should eql("Updated")
      page.should have_content(user.api_key)
    end

    it "hides the api key when editing an old account" do
      user = FactoryGirl.create(:api_user, :created_by => @current_admin.id, :created_at => Time.now - 15.minutes)
      visit "/admin/#/api_users/#{user.id}/edit"

      fill_in "Last Name", :with => "Updated"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.last_name.should eql("Updated")
      page.should_not have_content("API Key: #{user.api_key}")
    end
  end
end
