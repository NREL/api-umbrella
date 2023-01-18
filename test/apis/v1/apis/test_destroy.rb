require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestDestroy < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_audits_deletes
    # Create the record
    api = FactoryBot.create(:api_backend_with_all_relationships)
    server = api.servers.first
    assert(server)
    url_match = api.url_matches.first
    assert(url_match)
    rewrite = api.rewrites.first
    assert(rewrite)
    settings = api.settings
    assert(settings)
    settings_rate_limit = settings.rate_limits.first
    assert(settings_rate_limit)
    sub_settings = api.sub_settings.first
    assert(sub_settings)
    sub_settings_settings = sub_settings.settings
    assert(sub_settings_settings)
    sub_settings_rate_limit = sub_settings_settings.rate_limits.first
    assert(sub_settings_rate_limit)

    # Ensure it exists
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)
    assert_equal(1, ApiBackend.where(:id => api.id).count)
    assert_equal(1, ApiBackendServer.where(:id => server.id).count)
    assert_equal(1, ApiBackendUrlMatch.where(:id => url_match.id).count)
    assert_equal(1, ApiBackendRewrite.where(:id => rewrite.id).count)
    assert_equal(1, ApiBackendSettings.where(:id => settings.id).count)
    assert_equal(1, ApiBackendSubUrlSettings.where(:id => sub_settings.id).count)
    assert_equal(1, ApiBackendSettings.where(:id => sub_settings_settings.id).count)
    assert_equal(1, RateLimit.where(:id => settings_rate_limit.id).count)
    assert_equal(1, RateLimit.where(:id => sub_settings_rate_limit.id).count)

    # Delete
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(204, response)

    # Ensure it's deleted, including all the nested associations.
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(404, response)
    assert_equal(0, ApiBackend.where(:id => api.id).count)
    assert_equal(0, ApiBackendServer.where(:id => server.id).count)
    assert_equal(0, ApiBackendUrlMatch.where(:id => url_match.id).count)
    assert_equal(0, ApiBackendRewrite.where(:id => rewrite.id).count)
    assert_equal(0, ApiBackendSettings.where(:id => settings.id).count)
    assert_equal(0, ApiBackendSubUrlSettings.where(:id => sub_settings.id).count)
    assert_equal(0, ApiBackendSettings.where(:id => sub_settings_settings.id).count)
    assert_equal(0, RateLimit.where(:id => settings_rate_limit.id).count)
    assert_equal(0, RateLimit.where(:id => sub_settings_rate_limit.id).count)

    # Check the audit table, and ensure all the nested association tables are
    # also being audited.
    api_log = AuditLog.where("table_name = 'api_backends' AND action = 'D' AND row_data->>'id' = ?", api.id).first!
    assert_equal(api.name, api_log.row_data["name"])
    server_log = AuditLog.where("table_name = 'api_backend_servers' AND action = 'D' AND row_data->>'id' = ?", server.id).first!
    assert_equal(server.host, server_log.row_data["host"])
    url_match_log = AuditLog.where("table_name = 'api_backend_url_matches' AND action = 'D' AND row_data->>'id' = ?", url_match.id).first!
    assert_equal(url_match.frontend_prefix, url_match_log.row_data["frontend_prefix"])
    rewrite_log = AuditLog.where("table_name = 'api_backend_rewrites' AND action = 'D' AND row_data->>'id' = ?", rewrite.id).first!
    assert_equal(rewrite.frontend_matcher, rewrite_log.row_data["frontend_matcher"])
    settings_log = AuditLog.where("table_name = 'api_backend_settings' AND action = 'D' AND row_data->>'id' = ?", settings.id).first!
    assert_equal(settings.disable_api_key, settings_log.row_data["disable_api_key"])
    sub_settings_log = AuditLog.where("table_name = 'api_backend_sub_url_settings' AND action = 'D' AND row_data->>'id' = ?", sub_settings.id).first!
    assert_equal(sub_settings.regex, sub_settings_log.row_data["regex"])
    sub_settings_settings_log = AuditLog.where("table_name = 'api_backend_settings' AND action = 'D' AND row_data->>'id' = ?", sub_settings_settings.id).first!
    assert_equal(sub_settings_settings.disable_api_key, sub_settings_settings_log.row_data["disable_api_key"])
    settings_rate_limit_log = AuditLog.where("table_name = 'rate_limits' AND action = 'D' AND row_data->>'id' = ?", settings_rate_limit.id).first!
    assert_equal(settings_rate_limit.duration, settings_rate_limit_log.row_data["duration"])
    sub_settings_rate_limit_log = AuditLog.where("table_name = 'rate_limits' AND action = 'D' AND row_data->>'id' = ?", sub_settings_rate_limit.id).first!
    assert_equal(sub_settings_rate_limit.duration, sub_settings_rate_limit_log.row_data["duration"])
  end
end
