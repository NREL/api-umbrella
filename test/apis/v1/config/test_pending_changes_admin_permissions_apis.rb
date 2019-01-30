require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChangesAdminPermissionsApis < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    publish_default_config_version
    @api = FactoryBot.create(:api_backend)
    @google_api = FactoryBot.create(:google_api_backend)
    @google_extra_url_match_api = FactoryBot.create(:google_extra_url_match_api_backend)
    @yahoo_api = FactoryBot.create(:yahoo_api_backend)
    publish_api_backends([
      @api.id,
      @google_api.id,
      @google_extra_url_match_api.id,
      @yahoo_api.id,
    ])
  end

  def after_all
    super
    publish_default_config_version
  end

  def test_all_apis_for_superuser
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal([], data["config"]["apis"]["deleted"])
    assert_equal([], data["config"]["apis"]["modified"])
    assert_equal([], data["config"]["apis"]["new"])
    api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["id"] }
    assert_includes(api_ids, @api.id)
    assert_includes(api_ids, @google_api.id)
    assert_includes(api_ids, @google_extra_url_match_api.id)
    assert_includes(api_ids, @yahoo_api.id)
  end

  def test_permitted_apis_for_limited_admin
    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(google_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal([], data["config"]["apis"]["deleted"])
    assert_equal([], data["config"]["apis"]["modified"])
    assert_equal([], data["config"]["apis"]["new"])
    api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["id"] }
    assert_includes(api_ids, @google_api.id)
  end

  def test_excludes_forbidden_apis
    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(google_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal([], data["config"]["apis"]["deleted"])
    assert_equal([], data["config"]["apis"]["modified"])
    assert_equal([], data["config"]["apis"]["new"])
    api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["id"] }
    refute_includes(api_ids, @yahoo_api.id)
  end

  def test_excludes_partial_access_apis
    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(google_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal([], data["config"]["apis"]["deleted"])
    assert_equal([], data["config"]["apis"]["modified"])
    assert_equal([], data["config"]["apis"]["new"])
    api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["id"] }
    refute_includes(api_ids, @google_extra_url_match_api.id)
  end

  def test_exclude_apis_without_publish_permission
    unauthorized_google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_manage_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(unauthorized_google_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal([], data["config"]["apis"]["deleted"])
    assert_equal([], data["config"]["apis"]["modified"])
    assert_equal([], data["config"]["apis"]["new"])
    api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["id"] }
    assert_equal(0, api_ids.length)
  end
end
