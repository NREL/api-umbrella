require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChangesNew < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    publish_default_config_version
    @api = FactoryBot.create(:api_backend)
  end

  def after_all
    super
    publish_default_config_version
  end

  def test_new_if_never_published
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["config"]["apis"]["deleted"].length)
    assert_equal(0, data["config"]["apis"]["identical"].length)
    assert_equal(0, data["config"]["apis"]["modified"].length)
    assert_equal(1, data["config"]["apis"]["new"].length)
  end

  def test_new_if_created_since_publish
    publish_api_backends([@api.id])
    @google_api = FactoryBot.create(:google_api_backend)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(0, data["config"]["apis"]["deleted"].length)
    assert_equal(1, data["config"]["apis"]["identical"].length)
    assert_equal(0, data["config"]["apis"]["modified"].length)
    assert_equal(1, data["config"]["apis"]["new"].length)
  end

  def test_expected_output_for_new_apis
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    assert_equal("new", api_data["mode"])
    assert_equal(@api.id, api_data["id"])
    assert_equal(@api.name, api_data["name"])
    assert_nil(api_data["active"])
    assert_equal("", api_data["active_yaml"])
    assert_equal(@api.id, api_data["pending"]["id"])
    assert_includes(api_data["pending_yaml"], "frontend_host: #{@api.frontend_host}")
    refute_includes(api_data["pending_yaml"], "name: ")
  end
end
