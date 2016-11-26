require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChanges < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    setup_server
    Api.delete_all
    ConfigVersion.delete_all
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_grouped_into_categories
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_kind_of(Hash, data["config"])
    assert_kind_of(Hash, data["config"]["apis"])
    assert_kind_of(Array, data["config"]["apis"]["deleted"])
    assert_kind_of(Array, data["config"]["apis"]["identical"])
    assert_kind_of(Array, data["config"]["apis"]["modified"])
    assert_kind_of(Array, data["config"]["apis"]["new"])
  end

  def test_yaml_output_omits_separator
    FactoryGirl.create(:api)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    refute_includes(api_data["pending_yaml"], "---")
  end

  def test_yaml_output_omits_unnecessary_fields
    FactoryGirl.create(:api, :created_by => "foo", :updated_by => "foo")
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first
    %w(_id version created_by created_at updated_at updated_by).each do |field|
      assert_equal(true, api_data["pending"][field].present?)
      refute_includes(api_data["pending_yaml"], field)
    end
  end

  def test_yaml_output_sorts_fields_alphabetically
    FactoryGirl.create(:api, :sort_order => 10)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    api_data = data["config"]["apis"]["new"].first

    yaml_lines = api_data["pending_yaml"].split("\n")
    yaml_keys = yaml_lines.map { |line| line.gsub(/:.*/, "") }
    assert_equal([
      "backend_host",
      "backend_protocol",
      "balance_algorithm",
      "frontend_host",
      "name",
      "servers",
      "- host",
      "  port",
      "sort_order",
      "url_matches",
      "- backend_prefix",
      "  frontend_prefix",
    ], yaml_keys)
  end
end
