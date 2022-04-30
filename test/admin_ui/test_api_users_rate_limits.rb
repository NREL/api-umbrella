require_relative "../test_helper"

class Test::AdminUi::TestApiUsersRateLimits < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_add_custom_rate_limits
    user = FactoryBot.create(:api_user)
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    assert_field("Rate Limit", :with => "Default rate limits")
    select "Custom rate limits", :from => "Rate Limit"

    find("button", :text => /Add Rate Limit/).click
    within(".custom-rate-limits-table tbody tr:nth-child(1)") do
      find(".rate-limit-duration-in-units").set("1")
      find(".rate-limit-duration-units").select("minutes")
      find(".rate-limit-limit-by").select("IP Address")
      find(".rate-limit-limit").set("10")
      custom_input_trigger_click(find(".rate-limit-response-headers", :visible => :all))
    end

    find("button", :text => /Add Rate Limit/).click
    within(".custom-rate-limits-table tbody tr:nth-child(2)") do
      find(".rate-limit-duration-in-units").set("2")
      find(".rate-limit-duration-units").select("hours")
      find(".rate-limit-limit-by").select("IP Address")
      find(".rate-limit-limit").set("20")
      custom_input_trigger_click(find(".rate-limit-response-headers", :visible => :all))
    end

    find("button", :text => /Add Rate Limit/).click
    within(".custom-rate-limits-table tbody tr:nth-child(3)") do
      find(".rate-limit-duration-in-units").set("3")
      find(".rate-limit-duration-units").select("days")
      find(".rate-limit-limit-by").select("IP Address")
      find(".rate-limit-limit").set("30")
      custom_input_trigger_click(find(".rate-limit-response-headers", :visible => :all))
    end

    # Ensure the radio buttons/labels all have unique IDs, and we can select
    # the 2nd one.
    custom_input_trigger_click(find(".custom-rate-limits-table tbody tr:nth-child(2) .rate-limit-response-headers", :visible => :all))

    click_button("Save")
    assert_text("Successfully saved")

    user.reload

    assert_equal(3, user.settings.rate_limits.length)

    rate_limit = user.settings.rate_limits[0]
    assert_equal(60000, rate_limit.duration)
    assert_equal("ip", rate_limit.limit_by)
    assert_equal(10, rate_limit.limit_to)
    assert_equal(true, rate_limit.distributed)
    assert_equal(false, rate_limit.response_headers)

    rate_limit = user.settings.rate_limits[1]
    assert_equal(7200000, rate_limit.duration)
    assert_equal("ip", rate_limit.limit_by)
    assert_equal(20, rate_limit.limit_to)
    assert_equal(true, rate_limit.distributed)
    assert_equal(true, rate_limit.response_headers)

    rate_limit = user.settings.rate_limits[2]
    assert_equal(259200000, rate_limit.duration)
    assert_equal("ip", rate_limit.limit_by)
    assert_equal(30, rate_limit.limit_to)
    assert_equal(true, rate_limit.distributed)
    assert_equal(false, rate_limit.response_headers)
  end

  def test_edit_custom_rate_limits
    user = FactoryBot.create(:custom_rate_limit_api_user)
    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    within(".custom-rate-limits-table") do
      assert_equal("1", find(".rate-limit-duration-in-units").value)
      assert_equal("minutes", find(".rate-limit-duration-units").value)
      assert_equal("ip", find(".rate-limit-limit-by").value)
      assert_equal("500", find(".rate-limit-limit").value)
      assert_equal(true, find(".rate-limit-response-headers", :visible => :all).checked?)

      find(".rate-limit-limit").set("200")
    end

    click_button("Save")
    assert_text("Successfully saved")

    user.reload

    assert_equal(1, user.settings.rate_limits.length)
    rate_limit = user.settings.rate_limits.first
    assert_equal(200, rate_limit.limit_to)
  end

  def test_remove_custom_rate_limits
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:custom_rate_limit_api_user_settings, {
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
        ],
      }),
    })

    assert_equal(2, user.settings.rate_limits.length)

    admin_login
    visit "/admin/#/api_users/#{user.id}/edit"

    within(".custom-rate-limits-table") do
      click_link("Remove", :match => :first)
    end
    click_button("OK")

    click_button("Save")
    assert_text("Successfully saved")

    user.reload

    assert_equal(1, user.settings.rate_limits.length)
    rate_limit = user.settings.rate_limits.first
    assert_equal(20, rate_limit.limit_to)
  end
end
