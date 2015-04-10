require 'spec_helper'

describe "api users form", :js => true do
  login_admin

  describe "xss" do
    before(:all) do
      ApiUser.where(:registration_source.ne => "seed").delete_all
      @user = FactoryGirl.create(:xss_api_user)
    end

    it "escapes html entities in the table" do
      visit "/admin/#/api_users"

      page.should have_content(@user.email)
      page.should_not have_selector(".xss-test", :visible => :all)
      page.should have_content(@user.first_name)
      page.should have_content(@user.last_name)
      page.should have_content(@user.use_description)
      page.should have_content(@user.registration_source)
    end

    it "escapes html entities in the form" do
      visit "/admin/#/api_users/#{@user.id}/edit"

      find_field("E-mail").value.should eql(@user.email)
      page.should_not have_selector(".xss-test", :visible => :all)
      find_field("First Name").value.should eql(@user.first_name)
      find_field("Last Name").value.should eql(@user.last_name)
      find_field("Purpose").value.should eql(@user.use_description)
      page.should have_content(@user.registration_source)
    end
  end

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
      user.reload
      user.last_name.should eql("Updated")
      page.should have_content(user.api_key)
    end

    it "hides the api key when editing an old account" do
      user = FactoryGirl.create(:api_user, :created_by => @current_admin.id, :created_at => Time.now - 15.minutes)
      visit "/admin/#/api_users/#{user.id}/edit"

      fill_in "Last Name", :with => "Updated2"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user.reload
      user.last_name.should eql("Updated2")
      page.should_not have_content(user.api_key)
    end
  end

  describe "allowed ips input" do
    it "saves an empty input as nil" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.settings.allowed_ips.should eql(nil)
    end

    it "saves multiple lines (omitting blank lines) as an array" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      fill_in "Restrict Access to IPs", :with => "10.0.0.0/8\n\n\n\n127.0.0.1"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.settings.allowed_ips.should eql(["10.0.0.0/8", "127.0.0.1"])
    end

    it "displays an existing array as multiple lines" do
      user = FactoryGirl.create(:api_user, :settings => { :allowed_ips => ["10.0.0.0/24", "10.2.2.2"] })
      visit "/admin/#/api_users/#{user.id}/edit"

      find_field("Restrict Access to IPs").value.should eql("10.0.0.0/24\n10.2.2.2")
    end

    it "nullifies an existing array when an empty input is saved" do
      user = FactoryGirl.create(:api_user, :settings => { :allowed_ips => ["10.0.0.0/24", "10.2.2.2"] })
      visit "/admin/#/api_users/#{user.id}/edit"

      find_field("Restrict Access to IPs").value.should eql("10.0.0.0/24\n10.2.2.2")
      fill_in "Restrict Access to IPs", :with => ""
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user.reload
      user.settings.allowed_ips.should eql(nil)
    end
  end

  describe "allowed referers input" do
    it "saves an empty input as nil" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.settings.allowed_referers.should eql(nil)
    end

    it "saves multiple lines (omitting blank lines) as an array" do
      visit "/admin/#/api_users/new"

      fill_in "E-mail", :with => "example@example.com"
      fill_in "First Name", :with => "John"
      fill_in "Last Name", :with => "Doe"
      check "User agrees to the terms and conditions"
      fill_in "Restrict Access to HTTP Referers", :with => "*.example.com/*\n\n\n\nhttp://google.com/*"
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user = ApiUser.order_by(:created_at.asc).last
      user.settings.allowed_referers.should eql(["*.example.com/*", "http://google.com/*"])
    end

    it "displays an existing array as multiple lines" do
      user = FactoryGirl.create(:api_user, :settings => { :allowed_referers => ["*.example.com/*", "http://google.com/*"] })
      visit "/admin/#/api_users/#{user.id}/edit"

      find_field("Restrict Access to HTTP Referers").value.should eql("*.example.com/*\nhttp://google.com/*")
    end

    it "nullifies an existing array when an empty input is saved" do
      user = FactoryGirl.create(:api_user, :settings => { :allowed_referers => ["*.example.com/*", "http://google.com/*"] })
      visit "/admin/#/api_users/#{user.id}/edit"

      find_field("Restrict Access to HTTP Referers").value.should eql("*.example.com/*\nhttp://google.com/*")
      fill_in "Restrict Access to HTTP Referers", :with => ""
      click_button("Save")

      page.should have_content("Successfully saved the user")
      user.reload
      user.settings.allowed_referers.should eql(nil)
    end
  end
end
