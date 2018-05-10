require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPublishAdminPermissionsApis < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    Api.delete_all
    WebsiteBackend.delete_all
    ConfigVersion.delete_all
    @api = FactoryBot.create(:api)
    @google_api = FactoryBot.create(:google_api)
    @google_extra_url_match_api = FactoryBot.create(:google_extra_url_match_api)
    @yahoo_api = FactoryBot.create(:yahoo_api)
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_superusers_publish_anything
    config = {
      :apis => {
        @api.id => { :publish => "1" },
        @google_api.id => { :publish => "1" },
        @google_extra_url_match_api.id => { :publish => "1" },
        @yahoo_api.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = ConfigVersion.active_config
    assert_equal(4, active_config["apis"].length)
    assert_equal([
      @api.id,
      @google_api.id,
      @google_extra_url_match_api.id,
      @yahoo_api.id,
    ].sort, active_config["apis"].map { |api| api["_id"] }.sort)
  end

  def test_allow_limited_admins_publish_permitted_apis
    config = {
      :apis => {
        @google_api.id => { :publish => "1" },
      },
    }

    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(google_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = ConfigVersion.active_config
    assert_equal(1, active_config["apis"].length)
    assert_equal(@google_api.id, active_config["apis"].first["_id"])
  end

  def test_reject_limited_admins_publish_forbidden_apis
    config = {
      :apis => {
        @yahoo_api.id => { :publish => "1" },
      },
    }

    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(google_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_nil(ConfigVersion.active_config)
  end

  def test_reject_limited_admins_publish_partial_access_apis
    config = {
      :apis => {
        @google_extra_url_match_api.id => { :publish => "1" },
      },
    }

    google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(google_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_nil(ConfigVersion.active_config)
  end

  def test_reject_limited_admins_without_publish_permission
    config = {
      :apis => {
        @google_api.id => { :publish => "1" },
      },
    }

    unauthorized_google_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_manage_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(unauthorized_google_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_nil(ConfigVersion.active_config)
  end
end
