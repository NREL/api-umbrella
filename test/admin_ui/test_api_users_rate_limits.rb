require_relative "../test_helper"

class Test::AdminUi::TestApiUsersRateLimits < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
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
      assert_equal(true, find(".rate-limit-response-headers").checked?)

      find(".rate-limit-limit").set("200")
    end

    click_button("Save")
    assert_text("Successfully saved")

    user.reload

    assert_equal(1, user.settings.rate_limits.length)
    rate_limit = user.settings.rate_limits.first
    assert_equal(200, rate_limit.limit)
  end

  def test_remove_custom_rate_limits
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryBot.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryBot.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
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
    assert_equal(20, rate_limit.limit)
  end
end
