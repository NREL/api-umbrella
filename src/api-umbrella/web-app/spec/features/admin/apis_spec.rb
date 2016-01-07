require 'spec_helper'

describe "apis", :js => true do
  login_admin

  before(:each) do
    Api.delete_all
  end

  describe "reordering" do
    before(:each) do
      FactoryGirl.create(:api, :name => "API A", :sort_order => 3)
      FactoryGirl.create(:api, :name => "API B", :sort_order => 1)
      FactoryGirl.create(:api, :name => "API C", :sort_order => 2)
      FactoryGirl.create(:api, :name => "API testing-filter", :sort_order => 4)
    end

    it "shows the drag handle when the reorder button is clicked and hides when the done button is clicked" do
      visit "/admin/#/apis"

      all("tbody td.reorder-handle").length.should eql(0)
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      click_button "Done"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "removes filters when in reorder mode" do
      visit "/admin/#/apis"

      all("tbody tr").length.should eql(4)
      find(".dataTables_filter input").set("testing-fi")
      wait_for_datatables_filter
      all("tbody tr").length.should eql(1)
      click_button "Reorder"
      wait_for_datatables_filter
      all("tbody tr").length.should eql(4)
    end

    it "forces sorting by matching order when in reorder mode" do
      visit "/admin/#/apis"
      names = all("tbody td:first-child").map { |cell| cell.text }
      names.should eql(["API A", "API B", "API C", "API testing-filter"])
      click_button "Reorder"
      sleep 3
      names = all("tbody td:first-child").map { |cell| cell.text }
      names.should eql(["API B", "API C", "API A", "API testing-filter"])
    end

    it "exits reorder mode when a filter is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      find(".dataTables_filter input").set("testing-fi")
      wait_for_datatables_filter
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "exits reorder mode when an order is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      find("thead tr:first-child").click
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "performs reordering on drag" do
      visit "/admin/#/apis"

      names = Api.sorted.all.map { |api| api.name }
      names.should eql(["API B", "API C", "API A", "API testing-filter"])

      click_button "Reorder"

      # Simulate the drag and drop using jquery-simulate-ext (capybara supports
      # dropping, but not the dragging behavior jquery-ui needs).
      page.execute_script %{
        $('tbody td:contains("API A")')
          .siblings('td.reorder-handle')
          .simulate('drag-n-drop', { dy: -70 });
      }
      wait_for_ajax

      names = Api.sorted.all.map { |api| api.name }
      names.should eql(["API A", "API B", "API C", "API testing-filter"])
    end
  end

  describe "saving" do
    before(:each) do
      @api = FactoryGirl.create(:api_with_settings, :name => "Save Test API")
    end

    it "saves the record when only the nested object attributes contain changes" do
      @api.settings.error_data.should eql(nil)

      visit "/admin/#/apis"
      click_link "Save Test API"

      find_field("Name").value.should eql("Save Test API")

      find("legend a", :text => /Advanced Settings/).click
      page.execute_script %{
        ace.edit($('[data-form-property=api_key_missing]')[0]).setValue('hello1: foo\\nhello2: bar');
      }

      click_button("Save")
      page.should have_content("Successfully saved")

      @api = Api.find(@api.id)
      @api.settings.error_data.should eql({
        "api_key_missing" => {
          "hello1" => "foo",
          "hello2" => "bar",
        }
      })
    end
  end

  describe "loading" do
    before(:each) do
      @api = FactoryGirl.create(:api_with_settings, :name => "Test Load API", :frontend_host => "example1.com")
    end

    it "loads the record from the server each time the form opens, even if the data is pre-cached" do
      visit "/admin/#/apis"
      page.should have_content("Add API Backend")

      click_link "Test Load API"
      find_field("Frontend Host").value.should eql("example1.com")

      find("nav a", :text => /Configuration/).click
      find("nav a", :text => /API Backends/).click
      page.should have_content("Add API Backend")

      @api.frontend_host = "example2.com"
      @api.save!

      click_link "Test Load API"
      find_field("Frontend Host").value.should eql("example2.com")
    end
  end

  it "returns a validation error when all servers are removed from an existing API" do
    api = FactoryGirl.create(:api)
    visit "/admin/#/apis/#{api.id}/edit"
    find("#servers_table a", :text => /Remove/).click
    click_link("OK")
    click_button("Save")
    page.should have_content("must have at least one servers")

    api = Api.find(api.id)
    api.servers.length.should eql(1)
  end

  it "returns a validation error when all url prefixes are removed from an existing API" do
    api = FactoryGirl.create(:api)
    visit "/admin/#/apis/#{api.id}/edit"
    find("#url_matches_table a", :text => /Remove/).click
    click_link("OK")
    click_button("Save")
    page.should have_content("must have at least one url_matches")

    api = Api.find(api.id)
    api.url_matches.length.should eql(1)
  end

  it "shows the roles override checkbox only in the sub-settings" do
    visit "/admin/#/apis/new"

    find("legend a", :text => /Global Request Settings/).click
    page.should_not have_field('Override required roles from "Global Request Settings"')

    find("legend a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    within(".modal") do
      page.should have_field('Override required roles from "Global Request Settings"')
    end
  end

  it "defaults the frontend host to the current url's hostname" do
    visit "/admin/#/apis/new"
    page.should have_field("Frontend Host", :with => "127.0.0.1")
  end

  it "fills out and saves all the expected fields" do
    visit "/admin/#/apis/new"

    fill_in "Name", :with => "Testing API Backend"

    # Backend
    select "https", :from => "Backend Protocol"
    find("button", :text => /Add Server/).click
    within(".modal") do
      fill_in "Host", :with => "google.com"
      fill_in "Port", :with => "443"
      click_button("OK")
    end

    # Host
    fill_in "Frontend Host", :with => "api.foo.com"
    fill_in "Backend Host", :with => "api.bar.com"

    # Matching URL Prefixes
    find("button", :text => /Add URL Prefix/).click
    within(".modal") do
      fill_in "Frontend prefix", :with => "/foo"
      fill_in "Backend prefix", :with => "/bar"
      click_button("OK")
    end

    # Global Request Settings
    find("legend a", :text => /Global Request Settings/).click
    fill_in "Append Query String Parameters", :with => "foo=bar"
    fill_in "Set Request Headers", :with => "X-Foo1: Bar\nX-Bar2: Foo"
    fill_in "HTTP Basic Authentication", :with => "foo:bar"
    select "Optional - HTTPS is optional", :from => "HTTPS Requirements"
    select "Disabled - API keys are optional", :from => "API Key Checks"
    select "None - API keys can be used without any verification", :from => "API Key Verification Requirements"
    fill_in "Required Roles", :with => "some-role"
    find(".selectize-dropdown-content div", :text => /Add some-role/).click
    find("body").native.send_key(:Escape) # Sporadically seems necessary to reset selectize properly for second input.
    fill_in "Required Roles", :with => "some-role2"
    find(".selectize-dropdown-content div", :text => /Add some-role2/).click
    check "Via HTTP header"
    check "Via GET query parameter"
    select "Custom rate limits", :from => "Rate Limit"
    find("button", :text => /Add Rate Limit/).click
    within(".custom-rate-limits-table") do
      find(".rate-limit-duration-in-units").set("2")
      find(".rate-limit-duration-units").select("hours")
      find(".rate-limit-limit-by").select("IP Address")
      find(".rate-limit-limit").set("1500")
      find(".rate-limit-response-headers").click
    end
    select "IP Only - API key rate limits are ignored (only IP based limits are applied)", :from => "Anonymous Rate Limit Behavior"
    select "API Key Only - IP based rate limits are ignored (only API key limits are applied)", :from => "Authenticated Rate Limit Behavior"
    fill_in "Default Response Headers", :with => "X-Foo2: Bar\nX-Bar2: Foo"
    fill_in "Override Response Headers", :with => "X-Foo3: Bar\nX-Bar3: Foo"

    # Sub-URL Request Settings
    find("legend a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    within(".modal") do
      select "OPTIONS", :from => "Http method"
      fill_in "Regex", :with => "^/foo.*"
      select "Required & return message - HTTP requests will receive a message to use HTTPS", :from => "HTTPS Requirements"
      select "Disabled - API keys are optional", :from => "API Key Checks"
      select "E-mail verification required - Existing API keys will break, only new API keys will work if verified", :from => "API Key Verification Requirements"
      fill_in "Required Roles", :with => "sub-role"
      # Within this modal, selectize acts a bit funky in Capybara, so we have
      # to use javascript to click the add div, rather than Capybara like we do
      # in our other selectize tests.
      page.execute_script("$('.selectize-dropdown-content div').mousedown()")
      check 'Override required roles from "Global Request Settings"'
      check "Via HTTP header"
      check "Via GET query parameter"
      select "Custom rate limits", :from => "Rate Limit"
      find("button", :text => /Add Rate Limit/).click
      within(".custom-rate-limits-table") do
        find(".rate-limit-duration-in-units").set("3")
        find(".rate-limit-duration-units").select("minutes")
        find(".rate-limit-limit-by").select("IP Address")
        find(".rate-limit-limit").set("100")
        find(".rate-limit-response-headers").click
      end
      select "IP Only - API key rate limits are ignored (only IP based limits are applied)", :from => "Anonymous Rate Limit Behavior"
      select "API Key Only - IP based rate limits are ignored (only API key limits are applied)", :from => "Authenticated Rate Limit Behavior"
      fill_in "Default Response Headers", :with => "X-Sub-Foo2: Bar\nX-Sub-Bar2: Foo"
      fill_in "Override Response Headers", :with => "X-Sub-Foo3: Bar\nX-Sub-Bar3: Foo"
      click_button("OK")
    end

    # Advanced Requests Rewriting
    find("legend a", :text => /Advanced Requests Rewriting/).click
    find("button", :text => /Add Rewrite/).click
    within(".modal") do
      select "Regular Expression", :from => "Matcher type"
      select "PUT", :from => "Http method"
      fill_in "Frontend matcher", :with => "[0-9]+"
      fill_in "Backend replacement", :with => "number"
      click_button("OK")
    end

    # Advanced Settings
    find("legend a", :text => /Advanced Settings/).click
    fill_in "JSON Template", :with => '{"foo":"bar"}'
    fill_in "XML Template", :with => "<foo>bar</foo>"
    fill_in "CSV Template", :with => "foo,bar\nbar,foo"
    fill_in "Common (All Errors)", :with => "foo0: bar0\nbar0: foo0"
    fill_in "API Key Missing", :with => "foo1: bar1\nbar1: foo1"
    fill_in "API Key Invalid", :with => "foo2: bar2\nbar2: foo2"
    fill_in "API Key Disabled", :with => "foo3: bar3\nbar3: foo3"
    fill_in "API Key Unauthorized", :with => "foo4: bar4\nbar4: foo4"
    fill_in "Over Rate Limit", :with => "foo5: bar5\nbar5: foo5"
    fill_in "HTTPS Required", :with => "foo6: bar6\nbar6: foo6"

    click_button("Save")
    page.should have_content("Successfully saved")

    api = Api.desc(:created_at).first
    visit "/admin/#/apis/#{api.id}/edit"

    page.should have_field("Name", :with => "Testing API Backend")

    # Backend
    page.should have_select("Backend Protocol", :selected => "https")
    find("#servers_table a", :text => /Edit/).click
    within(".modal") do
      page.should have_field("Host", :with => "google.com")
      page.should have_field("Port", :with => "443")
      click_button("OK")
    end

    # Host
    page.should have_field("Frontend Host", :with => "api.foo.com")
    page.should have_field("Backend Host", :with => "api.bar.com")

    # Matching URL Prefixes
    find("#url_matches_table a", :text => /Edit/).click
    within(".modal") do
      page.should have_field("Frontend prefix", :with => "/foo")
      page.should have_field("Backend prefix", :with => "/bar")
      click_button("OK")
    end

    # Global Request Settings
    find("legend a", :text => /Global Request Settings/).click
    page.should have_field("Append Query String Parameters", :with => "foo=bar")
    page.should have_field("Set Request Headers", :with => "X-Foo1: Bar\nX-Bar2: Foo")
    page.should have_field("HTTP Basic Authentication", :with => "foo:bar")
    page.should have_select("HTTPS Requirements", :selected => "Optional - HTTPS is optional")
    page.should have_select("API Key Checks", :selected => "Disabled - API keys are optional")
    page.should have_select("API Key Verification Requirements", :selected => "None - API keys can be used without any verification")
    find_by_id(find_field("Required Roles")["data-raw-input-id"], :visible => :all).value.should eql("some-role,some-role2")
    find_by_id(find_field("Required Roles")["data-selectize-control-id"]).text.should eql("some-role×some-role2×")
    page.should have_checked_field("Via HTTP header")
    page.should have_checked_field("Via GET query parameter")
    page.should have_select("Rate Limit", :selected => "Custom rate limits")
    within(".custom-rate-limits-table") do
      find(".rate-limit-duration-in-units").value.should eql("2")
      find(".rate-limit-duration-units").value.should eql("hours")
      find(".rate-limit-limit-by").value.should eql("ip")
      find(".rate-limit-limit").value.should eql("1500")
      find(".rate-limit-response-headers").checked?.should eql(true)
    end
    page.should have_select("Anonymous Rate Limit Behavior", :selected => "IP Only - API key rate limits are ignored (only IP based limits are applied)")
    page.should have_select("Authenticated Rate Limit Behavior", :selected => "API Key Only - IP based rate limits are ignored (only API key limits are applied)")
    page.should have_field("Default Response Headers", :with => "X-Foo2: Bar\nX-Bar2: Foo")
    page.should have_field("Override Response Headers", :with => "X-Foo3: Bar\nX-Bar3: Foo")

    # Sub-URL Request Settings
    find("legend a", :text => /Sub-URL Request Settings/).click
    find("#sub_settings_table a", :text => /Edit/).click
    within(".modal") do
      page.should have_select("Http method", :selected => "OPTIONS")
      page.should have_field("Regex", :with => "^/foo.*")
      page.should have_select("HTTPS Requirements", :selected => "Required & return message - HTTP requests will receive a message to use HTTPS")
      page.should have_select("API Key Checks", :selected => "Disabled - API keys are optional")
      page.should have_select("API Key Verification Requirements", :selected => "E-mail verification required - Existing API keys will break, only new API keys will work if verified")
      find_by_id(find_field("Required Roles")["data-raw-input-id"], :visible => :all).value.should eql("sub-role")
      find_by_id(find_field("Required Roles")["data-selectize-control-id"]).text.should eql("sub-role×")
      page.should have_checked_field('Override required roles from "Global Request Settings"')
      page.should have_checked_field("Via HTTP header")
      page.should have_checked_field("Via GET query parameter")
      page.should have_select("Rate Limit", :selected => "Custom rate limits")
      within(".custom-rate-limits-table") do
        find(".rate-limit-duration-in-units").value.should eql("3")
        find(".rate-limit-duration-units").value.should eql("minutes")
        find(".rate-limit-limit-by").value.should eql("ip")
        find(".rate-limit-limit").value.should eql("100")
        find(".rate-limit-response-headers").checked?.should eql(true)
      end
      page.should have_select("Anonymous Rate Limit Behavior", :selected => "IP Only - API key rate limits are ignored (only IP based limits are applied)")
      page.should have_select("Authenticated Rate Limit Behavior", :selected => "API Key Only - IP based rate limits are ignored (only API key limits are applied)")
      page.should have_field("Default Response Headers", :with => "X-Sub-Foo2: Bar\nX-Sub-Bar2: Foo")
      page.should have_field("Override Response Headers", :with => "X-Sub-Foo3: Bar\nX-Sub-Bar3: Foo")
      click_button("OK")
    end

    # Advanced Requests Rewriting
    find("legend a", :text => /Advanced Requests Rewriting/).click
    find("#rewrites a", :text => /Edit/).click
    within(".modal") do
      page.should have_select("Matcher type", :selected => "Regular Expression")
      page.should have_select("Http method", :selected => "PUT")
      page.should have_field("Frontend matcher", :with => "[0-9]+")
      page.should have_field("Backend replacement", :with => "number")
      click_button("OK")
    end

    # Advanced Settings
    find("legend a", :text => /Advanced Settings/).click
    find_by_id(find_field("JSON Template")["data-raw-input-id"], :visible => :all).value.should eql('{"foo":"bar"}')
    find_by_id(find_field("JSON Template")["data-ace-content-id"]).text.should eql('{"foo":"bar"}')
    find_by_id(find_field("XML Template")["data-raw-input-id"], :visible => :all).value.should eql("<foo>bar</foo>")
    find_by_id(find_field("XML Template")["data-ace-content-id"]).text.should eql("<foo>bar</foo>")
    find_by_id(find_field("CSV Template")["data-raw-input-id"], :visible => :all).value.should eql("foo,bar\nbar,foo")
    find_by_id(find_field("CSV Template")["data-ace-content-id"]).text.should eql("foo,bar bar,foo")
    find_by_id(find_field("API Key Missing")["data-raw-input-id"], :visible => :all).value.should eql("foo1: bar1\nbar1: foo1")
    find_by_id(find_field("API Key Missing")["data-ace-content-id"]).text.should eql("foo1: bar1 bar1: foo1")
    find_by_id(find_field("API Key Invalid")["data-raw-input-id"], :visible => :all).value.should eql("foo2: bar2\nbar2: foo2")
    find_by_id(find_field("API Key Invalid")["data-ace-content-id"]).text.should eql("foo2: bar2 bar2: foo2")
    find_by_id(find_field("API Key Disabled")["data-raw-input-id"], :visible => :all).value.should eql("foo3: bar3\nbar3: foo3")
    find_by_id(find_field("API Key Disabled")["data-ace-content-id"]).text.should eql("foo3: bar3 bar3: foo3")
    find_by_id(find_field("API Key Unauthorized")["data-raw-input-id"], :visible => :all).value.should eql("foo4: bar4\nbar4: foo4")
    find_by_id(find_field("API Key Unauthorized")["data-ace-content-id"]).text.should eql("foo4: bar4 bar4: foo4")
    find_by_id(find_field("Over Rate Limit")["data-raw-input-id"], :visible => :all).value.should eql("foo5: bar5\nbar5: foo5")
    find_by_id(find_field("Over Rate Limit")["data-ace-content-id"]).text.should eql("foo5: bar5 bar5: foo5")
  end

  it "edits custom rate limits" do
    api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.build(:custom_rate_limit_api_setting),
    })
    visit "/admin/#/apis/#{api.id}/edit"

    find("legend a", :text => /Global Request Settings/).click
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

    api.reload

    api.settings.rate_limits.length.should eql(1)
    rate_limit = api.settings.rate_limits.first
    rate_limit.limit.should eql(200)
  end
end
