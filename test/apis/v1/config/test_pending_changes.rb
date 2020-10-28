require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChanges < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    publish_default_config_version
  end

  def after_all
    super
    publish_default_config_version
  end

  def test_grouped_into_categories
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_kind_of(Hash, data["config"])
    assert_kind_of(Hash, data["config"]["apis"])
    assert_kind_of(Array, data["config"]["apis"]["deleted"])
    assert_kind_of(Array, data["config"]["apis"]["identical"])
    assert_kind_of(Array, data["config"]["apis"]["modified"])
    assert_kind_of(Array, data["config"]["apis"]["new"])
  end

  def test_yaml_output_omits_separator
    FactoryBot.create(:api_backend)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    refute_includes(api_data["pending_yaml"], "---")
    refute_includes(api_data["pending_yaml"], "...")
  end

  def test_yaml_output_omits_unnecessary_fields
    FactoryBot.create(:api_backend, :created_by_username => "foo", :updated_by_username => "foo")
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    pending_keys = api_data["pending"].keys
    [
      "created_at",
      "created_by",
      "creator",
      "id",
      "updated_at",
      "updated_by",
      "updater",
      "version",
    ].each do |field|
      assert_includes(pending_keys, field)
      refute_includes(api_data["pending_yaml"], field)
    end
    [
      "created_by_id",
      "created_by_username",
      "updated_by_id",
      "updated_by_username",
    ].each do |field|
      refute_includes(pending_keys, field)
      refute_includes(api_data["pending_yaml"], field)
    end
  end

  def test_yaml_output_sorts_fields_alphabetically
    FactoryBot.create(:api_backend)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first

    yaml_lines = api_data["pending_yaml"].split("\n")
    yaml_keys = yaml_lines.map { |line| line.gsub(/:.*/, "") }
    assert_equal([
      "backend_host",
      "backend_protocol",
      "balance_algorithm",
      "frontend_host",
      "servers",
      "- host",
      "  port",
      "url_matches",
      "- backend_prefix",
      "  frontend_prefix",
    ], yaml_keys)
  end
end
