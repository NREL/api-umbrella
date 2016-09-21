require "test_helper"

class TestAdminUiStatsUsers < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    ElasticsearchHelper.clean_es_indices(["2014-11", "2015-01", "2015-03"])
  end

  def test_xss_escaping_in_table
    user = FactoryGirl.create(:xss_api_user)
    FactoryGirl.create(:xss_log_item, {
      :request_at => Time.parse("2015-01-16T06:06:28.816Z").utc,
      :api_key => user.api_key,
      :user_id => user.id,
      :user_email => user.email,
      :user_registration_source => user.registration_source,
    })
    LogItem.gateway.refresh_index!

    admin_login
    visit "/admin/#/stats/users?tz=America%2FDenver&search=&start_at=2015-01-12&end_at=2015-01-18&interval=day"
    refute_selector(".busy-blocker")

    assert_text(user.email)
    assert_text(user.first_name)
    assert_text(user.last_name)
    assert_text(user.use_description)
    refute_selector(".xss-test", :visible => :all)
  end
end
