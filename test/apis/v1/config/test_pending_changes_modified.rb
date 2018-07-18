require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChangesModified < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    Api.delete_all
    WebsiteBackend.delete_all
    ConfigVersion.delete_all

    @api = FactoryBot.create(:api, :name => "Before")
    ConfigVersion.publish!(ConfigVersion.pending_config)
    @api.update(:name => "After")
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_modified_if_changes_since_publish
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["config"]["apis"]["deleted"].length)
    assert_equal(0, data["config"]["apis"]["identical"].length)
    assert_equal(1, data["config"]["apis"]["modified"].length)
    assert_equal(0, data["config"]["apis"]["new"].length)
  end

  def test_expected_output_for_modified_apis
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["modified"].first
    assert_equal("modified", api_data["mode"])
    assert_equal(@api.id, api_data["id"])
    assert_equal("After", api_data["name"])
    assert_equal("Before", api_data["active"]["name"])
    assert_includes(api_data["active_yaml"], "name: Before")
    assert_equal("After", api_data["pending"]["name"])
    assert_includes(api_data["pending_yaml"], "name: After")
  end
end
