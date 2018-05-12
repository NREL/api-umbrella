require_relative "../test_helper"

class Test::AdminUi::TestApis < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server

    Api.delete_all
  end

  def test_saves_when_only_nested_fields_change
    api = FactoryBot.create(:api_with_settings, :name => "Save Test API")
    assert_nil(api.settings.error_data)

    admin_login
    visit "/admin/#/apis"
    click_link "Save Test API"

    assert_equal("Save Test API", find_field("Name").value)

    find("legend a", :text => /Advanced Settings/).click
    fill_in "API Key Missing", :with => "hello1: foo\nhello2: bar", :visible => :all

    click_button("Save")
    assert_text("Successfully saved")

    api = Api.find(api.id)
    assert_equal({
      "api_key_missing" => {
        "hello1" => "foo",
        "hello2" => "bar",
      },
    }, api.settings.error_data)
  end

  def test_loads_from_server_on_each_load
    api = FactoryBot.create(:api_with_settings, :name => "Test Load API", :frontend_host => "example1.com")
    admin_login
    visit "/admin/#/apis"
    assert_text("Add API Backend")

    click_link "Test Load API"
    assert_equal("example1.com", find_field("Frontend Host").value)

    find("nav a", :text => /Configuration/).click
    find("nav a", :text => /API Backends/).click
    assert_text("Add API Backend")

    api.frontend_host = "example2.com"
    api.save!

    click_link "Test Load API"
    assert_equal("example2.com", find_field("Frontend Host").value)
  end

  def test_validation_error_when_all_servers_removed_from_existing_api
    api = FactoryBot.create(:api)
    admin_login
    visit "/admin/#/apis/#{api.id}/edit"
    find("#servers_table a", :text => /Remove/).click
    click_button("OK")
    click_button("Save")
    assert_text("Must have at least one servers")

    api = Api.find(api.id)
    assert_equal(1, api.servers.length)
  end

  def test_validation_error_when_all_url_prefixes_removed_from_existing_api
    api = FactoryBot.create(:api)
    admin_login
    visit "/admin/#/apis/#{api.id}/edit"
    find("#url_matches_table a", :text => /Remove/).click
    click_button("OK")
    click_button("Save")
    assert_text("Must have at least one url_matches")

    api = Api.find(api.id)
    assert_equal(1, api.url_matches.length)
  end

  def test_roles_override_checkbox_only_in_sub_settings
    admin_login
    visit "/admin/#/apis/new"

    find("legend a", :text => /Global Request Settings/).click
    refute_field('Override required roles from "Global Request Settings"')

    find("legend a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    assert_selector(".modal")
    within(".modal") do
      assert_field('Override required roles from "Global Request Settings"')
    end
  end

  def test_defaults_frontend_host_to_current_url_hostname
    admin_login
    visit "/admin/#/apis/new"
    assert_field("Frontend Host", :with => "127.0.0.1")
  end

  def test_form
    admin_login
    visit "/admin/#/apis/new"

    fill_in "Name", :with => "Testing API Backend"

    # Backend
    select "https", :from => "Backend Protocol"
    find("button", :text => /Add Server/).click
    assert_selector(".modal")
    within(".modal") do
      fill_in "Host", :with => "google.com"
      assert_field("Port", :with => "443")
      click_button("OK")
    end

    # Host
    fill_in "Frontend Host", :with => "api.foo.com"
    fill_in "Backend Host", :with => "api.bar.com"

    # Matching URL Prefixes
    find("button", :text => /Add URL Prefix/).click
    assert_selector(".modal")
    within(".modal") do
      fill_in "Frontend Prefix", :with => "/foo"
      fill_in "Backend Prefix", :with => "/bar"
      assert_text("Incoming Frontend Request: https://api.foo.com/fooexample.json?param=value")
      assert_text("Outgoing Backend Request: https://api.bar.com/barexample.json?param=value")
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
    find(".selectize-dropdown-content div.create", :text => /Add some-role/).click
    find("body").send_keys(:escape)
    fill_in "Required Roles", :with => "some-role2"
    find(".selectize-dropdown-content div.create", :text => /Add some-role2/).click
    find("body").send_keys(:escape)
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
    assert_selector(".modal")
    within(".modal") do
      select "OPTIONS", :from => "HTTP Method"
      fill_in "Regex", :with => "^/foo.*"
      select "Required - HTTP requests will receive a message to use HTTPS", :from => "HTTPS Requirements"
      select "Disabled - API keys are optional", :from => "API Key Checks"
      select "E-mail verification required - Existing API keys will break, only new API keys will work if verified", :from => "API Key Verification Requirements"
      # FIXME: Without this sleep, then the selectize test below will randomly
      # fail sometimes. Not exactly sure why, but nothing gets filled in and
      # the selectize dropdown doesn't show up.
      sleep 1
      fill_in "Required Roles", :with => "sub-role"
    end
    find(".selectize-dropdown-content div.create", :text => /Add sub-role/).click
    find("body").send_keys(:escape)
    within(".modal") do
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
    assert_selector(".modal")
    within(".modal") do
      select "Regular Expression", :from => "Matcher Type"
      select "PUT", :from => "HTTP Method"
      fill_in "Frontend Matcher", :with => "[0-9]+"
      fill_in "Backend Replacement", :with => "number"
      click_button("OK")
    end

    # Advanced Settings
    find("legend a", :text => /Advanced Settings/).click
    fill_in "JSON Template", :with => '{"foo":"bar"}', :visible => :all
    fill_in "XML Template", :with => "<foo>bar</foo>", :visible => :all
    fill_in "CSV Template", :with => "foo,bar\nbar,foo", :visible => :all
    fill_in "Common (All Errors)", :with => "foo0: bar0\nbar0: foo0", :visible => :all
    fill_in "API Key Missing", :with => "foo1: bar1\nbar1: foo1", :visible => :all
    fill_in "API Key Invalid", :with => "foo2: bar2\nbar2: foo2", :visible => :all
    fill_in "API Key Disabled", :with => "foo3: bar3\nbar3: foo3", :visible => :all
    fill_in "API Key Unauthorized", :with => "foo4: bar4\nbar4: foo4", :visible => :all
    fill_in "Over Rate Limit", :with => "foo5: bar5\nbar5: foo5", :visible => :all
    fill_in "HTTPS Required", :with => "foo6: bar6\nbar6: foo6", :visible => :all

    click_button("Save")
    assert_text("Successfully saved")

    api = Api.desc(:created_at).first
    visit "/admin/#/apis/#{api.id}/edit"

    assert_field("Name", :with => "Testing API Backend")

    # Backend
    assert_select("Backend Protocol", :selected => "https")
    find("#servers_table a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_field("Host", :with => "google.com")
      assert_field("Port", :with => "443")
      click_button("OK")
    end

    # Host
    assert_field("Frontend Host", :with => "api.foo.com")
    assert_field("Backend Host", :with => "api.bar.com")

    # Matching URL Prefixes
    find("#url_matches_table a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_field("Frontend Prefix", :with => "/foo")
      assert_field("Backend Prefix", :with => "/bar")
      click_button("OK")
    end

    # Global Request Settings
    find("legend a", :text => /Global Request Settings/).click
    assert_field("Append Query String Parameters", :with => "foo=bar")
    assert_field("Set Request Headers", :with => "X-Foo1: Bar\nX-Bar2: Foo")
    assert_field("HTTP Basic Authentication", :with => "foo:bar")
    assert_select("HTTPS Requirements", :selected => "Optional - HTTPS is optional")
    assert_select("API Key Checks", :selected => "Disabled - API keys are optional")
    assert_select("API Key Verification Requirements", :selected => "None - API keys can be used without any verification")
    field = find_field("Required Roles")
    assert_selector("#" + field["data-selectize-control-id"], :text => "some-role×some-role2×")
    assert_equal("some-role,some-role2", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    assert_checked_field("Via HTTP header")
    assert_checked_field("Via GET query parameter")
    assert_select("Rate Limit", :selected => "Custom rate limits")
    within(".custom-rate-limits-table") do
      assert_equal("2", find(".rate-limit-duration-in-units").value)
      assert_equal("hours", find(".rate-limit-duration-units").value)
      assert_equal("ip", find(".rate-limit-limit-by").value)
      assert_equal("1500", find(".rate-limit-limit").value)
      assert_equal(true, find(".rate-limit-response-headers").checked?)
    end
    assert_select("Anonymous Rate Limit Behavior", :selected => "IP Only - API key rate limits are ignored (only IP based limits are applied)")
    assert_select("Authenticated Rate Limit Behavior", :selected => "API Key Only - IP based rate limits are ignored (only API key limits are applied)")
    assert_field("Default Response Headers", :with => "X-Foo2: Bar\nX-Bar2: Foo")
    assert_field("Override Response Headers", :with => "X-Foo3: Bar\nX-Bar3: Foo")

    # Sub-URL Request Settings
    find("legend a", :text => /Sub-URL Request Settings/).click
    find("#sub_settings_table a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_select("HTTP Method", :selected => "OPTIONS")
      assert_field("Regex", :with => "^/foo.*")
      assert_select("HTTPS Requirements", :selected => "Required - HTTP requests will receive a message to use HTTPS")
      assert_select("API Key Checks", :selected => "Disabled - API keys are optional")
      assert_select("API Key Verification Requirements", :selected => "E-mail verification required - Existing API keys will break, only new API keys will work if verified")
      field = find_field("Required Roles")
      assert_selector("#" + field["data-selectize-control-id"], :text => "sub-role×")
      assert_equal("sub-role", find_by_id(field["data-raw-input-id"], :visible => :all).value)
      assert_checked_field('Override required roles from "Global Request Settings"')
      assert_checked_field("Via HTTP header")
      assert_checked_field("Via GET query parameter")
      assert_select("Rate Limit", :selected => "Custom rate limits")
      within(".custom-rate-limits-table") do
        assert_equal("3", find(".rate-limit-duration-in-units").value)
        assert_equal("minutes", find(".rate-limit-duration-units").value)
        assert_equal("ip", find(".rate-limit-limit-by").value)
        assert_equal("100", find(".rate-limit-limit").value)
        assert_equal(true, find(".rate-limit-response-headers").checked?)
      end
      assert_select("Anonymous Rate Limit Behavior", :selected => "IP Only - API key rate limits are ignored (only IP based limits are applied)")
      assert_select("Authenticated Rate Limit Behavior", :selected => "API Key Only - IP based rate limits are ignored (only API key limits are applied)")
      assert_field("Default Response Headers", :with => "X-Sub-Foo2: Bar\nX-Sub-Bar2: Foo")
      assert_field("Override Response Headers", :with => "X-Sub-Foo3: Bar\nX-Sub-Bar3: Foo")
      click_button("OK")
    end

    # Advanced Requests Rewriting
    find("legend a", :text => /Advanced Requests Rewriting/).click
    find("#rewrites a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_select("Matcher Type", :selected => "Regular Expression")
      assert_select("HTTP Method", :selected => "PUT")
      assert_field("Frontend Matcher", :with => "[0-9]+")
      assert_field("Backend Replacement", :with => "number")
      click_button("OK")
    end

    # Advanced Settings
    find("legend a", :text => /Advanced Settings/).click
    field = find_field("JSON Template", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => '{"foo":"bar"}')
    assert_equal('{"foo":"bar"}', find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("XML Template", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "<foo>bar</foo>")
    assert_equal("<foo>bar</foo>", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("CSV Template", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo,bar\nbar,foo")
    assert_equal("foo,bar\nbar,foo", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("API Key Missing", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo1: bar1\nbar1: foo1")
    assert_equal("foo1: bar1\nbar1: foo1", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("API Key Invalid", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo2: bar2\nbar2: foo2")
    assert_equal("foo2: bar2\nbar2: foo2", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("API Key Disabled", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo3: bar3\nbar3: foo3")
    assert_equal("foo3: bar3\nbar3: foo3", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("API Key Unauthorized", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo4: bar4\nbar4: foo4")
    assert_equal("foo4: bar4\nbar4: foo4", find_by_id(field["data-raw-input-id"], :visible => :all).value)
    field = find_field("Over Rate Limit", :visible => :all)
    assert_selector("#" + field["data-ace-content-id"], :text => "foo5: bar5\nbar5: foo5")
    assert_equal("foo5: bar5\nbar5: foo5", find_by_id(field["data-raw-input-id"], :visible => :all).value)
  end

  def test_edit_custom_rate_limits
    api = FactoryBot.create(:api, {
      :settings => FactoryBot.build(:custom_rate_limit_api_setting),
    })
    admin_login
    visit "/admin/#/apis/#{api.id}/edit"

    find("legend a", :text => /Global Request Settings/).click
    within(".custom-rate-limits-table") do
      assert_equal("1", find(".rate-limit-duration-in-units").value)
      assert_equal("minutes", find(".rate-limit-duration-units").value)
      assert_equal("ip", find(".rate-limit-limit-by").value)
      assert_equal("500", find(".rate-limit-limit").value)
      assert_equal(true, find(".rate-limit-response-headers").checked?)

      find(".rate-limit-limit").set("200")
    end

    click_button("Save")
    assert_text("Successfully saved")

    api.reload

    assert_equal(1, api.settings.rate_limits.length)
    rate_limit = api.settings.rate_limits.first
    assert_equal(200, rate_limit.limit)
  end

  def test_nested_select_menu_behavior_inside_modals
    api = FactoryBot.create(:api, :name => unique_test_id)
    admin_login
    visit "/admin/#/apis/#{api.id}/edit"

    # Add a sub-url setting.
    find("legend a", :text => /Sub-URL Request Settings/).click
    find("button", :text => /Add URL Settings/).click
    assert_selector(".modal")
    within(".modal") do
      fill_in "Regex", :with => "^/foo.*"
      click_button("OK")
    end

    # Ensure the item got added to the table.
    assert_selector("#sub_settings_table")
    within("#sub_settings_table") do
      # "any" for the HTTP Method should be shown despite not being explicitly
      # selected (since it's the default/first option).
      assert_text("any")
      assert_text("^/foo.*")
    end

    # Save the API.
    click_button("Save")
    assert_text("Successfully saved")

    # Edit again.
    click_link api.name

    # Verify the sub-url setting in the table.
    find("legend a", :text => /Sub-URL Request Settings/).click
    assert_selector("#sub_settings_table")
    within("#sub_settings_table") do
      assert_text("any")
      assert_text("^/foo.*")
    end

    # Verify the sub-url setting in the modal and make explicit change the HTTP
    # method select.
    find("#sub_settings_table a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_select("HTTP Method", :selected => "Any")

      # Make another change.
      select "OPTIONS", :from => "HTTP Method"
      click_button("OK")
    end
    assert_selector("#sub_settings_table")
    within("#sub_settings_table") do
      assert_text("OPTIONS")
      assert_text("^/foo.*")
    end

    # Save the API.
    click_button("Save")
    assert_text("Successfully saved")

    # Edit again.
    click_link api.name

    # Verify all of the edit updates are displayed properly (we saw an issue
    # where the select menu handling didn't work properly on the second display
    # of an edited record).
    find("legend a", :text => /Sub-URL Request Settings/).click
    assert_selector("#sub_settings_table")
    within("#sub_settings_table") do
      assert_text("OPTIONS")
      assert_text("^/foo.*")
    end
    find("#sub_settings_table a", :text => /Edit/).click
    assert_selector(".modal")
    within(".modal") do
      assert_select("HTTP Method", :selected => "OPTIONS")
    end
  end
end
