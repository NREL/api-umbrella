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
      page.should have_content(@user.first_name)
      page.should have_content(@user.last_name)
      page.should have_content(@user.use_description)
      page.should have_content(@user.registration_source)
      page.should_not have_selector(".xss-test", :visible => :all)
    end

    it "escapes html entities in the form" do
      visit "/admin/#/api_users/#{@user.id}/edit"

      find_field("E-mail").value.should eql(@user.email)
      find_field("First Name").value.should eql(@user.first_name)
      find_field("Last Name").value.should eql(@user.last_name)
      find_field("Purpose").value.should eql(@user.use_description)
      page.should have_content(@user.registration_source)
      page.should_not have_selector(".xss-test", :visible => :all)
    end

    it "escapes html entities in flash confirmation message" do
      visit "/admin/#/api_users/#{@user.id}/edit"

      fill_in "Last Name", :with => "Doe"
      click_button("Save")

      page.should have_content("Successfully saved the user \"#{@user.email}\"")
      page.should_not have_selector(".xss-test", :visible => :all)
    end
  end

  describe "api key visibility" do
    it "shows the api key in the save notification when creating a new account" do
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

    it "allows the full api key to be revealed when the admin has permissions" do
      user = FactoryGirl.create(:api_user, :created_by => @current_admin.id, :created_at => Time.now - 2.weeks + 5.minutes)
      visit "/admin/#/api_users/#{user.id}/edit"

      page.should have_content(user.api_key_preview)
      page.should_not have_content(user.api_key)
      page.should have_link("(reveal)")
      click_link("(reveal)")
      page.should have_content(user.api_key)
      page.should_not have_content(user.api_key_preview)
      page.should_not have_link("(reveal)")
      page.should have_link("(hide)")
      click_link("(hide)")
      page.should have_content(user.api_key_preview)
      page.should_not have_content(user.api_key)
      page.should have_link("(reveal)")
    end

    describe "limited admin is logged in" do
      let(:current_admin) { FactoryGirl.create(:limited_admin) }
      login_admin

      it "hides the full api key when the admin does not have permissions" do
        user = FactoryGirl.create(:api_user, :created_by => @current_admin.id, :created_at => (Time.now - 2.weeks - 5.minutes))
        visit "/admin/#/api_users/#{user.id}/edit"

        page.should have_content(user.api_key_preview)
        page.should_not have_content(user.api_key)
        page.should_not have_link("(reveal)")
      end
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

  describe "welcome e-mail" do
    before(:each) do
      Delayed::Worker.delay_jobs = false
      ActionMailer::Base.deliveries.clear
    end

    after(:each) do
      Delayed::Worker.delay_jobs = true
    end

    it "defaults to not sending it when signing up via the admin" do
      expect do
        visit "/admin/#/api_users/new"

        fill_in "E-mail", :with => "example@example.com"
        fill_in "First Name", :with => "John"
        fill_in "Last Name", :with => "Doe"
        check "User agrees to the terms and conditions"
        click_button("Save")
        page.should have_content("Successfully saved the user")
      end.to change { ActionMailer::Base.deliveries.count }.by(0)
    end

    it "sends the e-mail when explicitly asked for" do
      expect do
        visit "/admin/#/api_users/new"

        fill_in "E-mail", :with => "example@example.com"
        fill_in "First Name", :with => "John"
        fill_in "Last Name", :with => "Doe"
        check "User agrees to the terms and conditions"
        check "Send user welcome e-mail with API key information"
        click_button("Save")
        page.should have_content("Successfully saved the user")
      end.to change { ActionMailer::Base.deliveries.count }.by(1)
    end
  end

  it "fills out and saves all the expected fields" do
    visit "/admin/#/api_users/new"

    # User Info
    fill_in "E-mail", :with => "example@example.com"
    fill_in "First Name", :with => "John"
    fill_in "Last Name", :with => "Doe"
    check "User agrees to the terms and conditions"

    # Rate Limiting
    select "Custom rate limits", :from => "Rate Limit"
    find("button", :text => /Add Rate Limit/).click
    within(".custom-rate-limits-table") do
      find(".rate-limit-duration-in-units").set("2")
      find(".rate-limit-duration-units").select("hours")
      find(".rate-limit-limit-by").select("IP Address")
      find(".rate-limit-limit").set("1500")
      find(".rate-limit-response-headers").click
    end
    select "Rate limit by IP address", :from => "Limit By"

    # Permissions
    fill_in "Roles", :with => "some-user-role"
    find(".selectize-dropdown-content div", :text => /Add some-user-role/).click
    find("body").native.send_key(:Escape) # Sporadically seems necessary to reset selectize properly for second input.
    fill_in "Roles", :with => "some-user-role2"
    find(".selectize-dropdown-content div", :text => /Add some-user-role2/).click
    fill_in "Restrict Access to IPs", :with => "127.0.0.1\n10.1.1.1/16"
    fill_in "Restrict Access to HTTP Referers", :with => "*.example.com/*\n*//example2.com/*"
    select "Disabled", :from => "Account Enabled"

    click_button("Save")
    page.should have_content("Successfully saved")

    user = ApiUser.desc(:created_at).first
    visit "/admin/#/api_users/#{user.id}/edit"

    # User Info
    page.should have_field("E-mail", :with => "example@example.com")
    page.should have_field("First Name", :with => "John")
    page.should have_field("Last Name", :with => "Doe")

    # Rate Limiting
    page.should have_select("Rate Limit", :selected => "Custom rate limits")
    within(".custom-rate-limits-table") do
      find(".rate-limit-duration-in-units").value.should eql("2")
      find(".rate-limit-duration-units").value.should eql("hours")
      find(".rate-limit-limit-by").value.should eql("ip")
      find(".rate-limit-limit").value.should eql("1500")
      find(".rate-limit-response-headers").checked?.should eql(true)
    end
    page.should have_select("Limit By", :selected => "Rate limit by IP address")

    # Permissions
    find_by_id(find_field("Roles")["data-raw-input-id"], :visible => :all).value.should eql("some-user-role,some-user-role2")
    find_by_id(find_field("Roles")["data-selectize-control-id"]).text.should eql("some-user-role×some-user-role2×")
    page.should have_field("Restrict Access to IPs", :with => "127.0.0.1\n10.1.1.1/16")
    page.should have_field("Restrict Access to HTTP Referers", :with => "*.example.com/*\n*//example2.com/*")
    page.should have_select("Account Enabled", :selected => "Disabled")
  end

  it "edits custom rate limits" do
    user = FactoryGirl.create(:custom_rate_limit_api_user)
    visit "/admin/#/api_users/#{user.id}/edit"

    within(".custom-rate-limits-table") do
      find(".rate-limit-duration-in-units").value.should eql("1")
      find(".rate-limit-duration-units").value.should eql("minutes")
      find(".rate-limit-limit-by").value.should eql("ip")
      find(".rate-limit-limit").value.should eql("500")
      find(".rate-limit-response-headers").checked?.should eql(true)

      find(".rate-limit-limit").set("200")
    end

    click_button("Save")
    page.should have_content("Successfully saved")

    user.reload

    user.settings.rate_limits.length.should eql(1)
    rate_limits = user.settings.rate_limits.first
    rate_limits.limit.should eql(200)
  end

end
