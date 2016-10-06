require_relative "../../../test_helper"

class TestApisV1ConfigPendingChangesNew < Minitest::Capybara::Test
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
    Api.delete_all
    ConfigVersion.delete_all

    @api = FactoryGirl.create(:api)
  end

  def test_new_if_never_published
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", @@http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(0, data["config"]["apis"]["deleted"].length)
    assert_equal(0, data["config"]["apis"]["identical"].length)
    assert_equal(0, data["config"]["apis"]["modified"].length)
    assert_equal(1, data["config"]["apis"]["new"].length)
  end

  def test_new_if_created_since_publish
    ConfigVersion.publish!(ConfigVersion.pending_config)
    @google_api = FactoryGirl.create(:google_api)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", @@http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(0, data["config"]["apis"]["deleted"].length)
    assert_equal(1, data["config"]["apis"]["identical"].length)
    assert_equal(0, data["config"]["apis"]["modified"].length)
    assert_equal(1, data["config"]["apis"]["new"].length)
  end

  def test_expected_output_for_new_apis
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", @@http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    assert_equal("new", api_data["mode"])
    assert_equal(@api.id, api_data["id"])
    assert_equal(@api.name, api_data["name"])
    assert_equal(nil, api_data["active"])
    assert_equal("", api_data["active_yaml"])
    assert_equal(@api.id, api_data["pending"]["_id"])
    assert_includes(api_data["pending_yaml"], "name: #{@api.name}")
  end
end
