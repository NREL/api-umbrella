require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPublishAdminPermissionsWebsites < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    publish_default_config_version
    @localhost_website = FactoryBot.create(:website_backend_localhost)
    @example_com_website = FactoryBot.create(:example_com_website_backend)
  end

  def after_all
    super
    publish_default_config_version
  end

  def test_superusers_publish_anything
    config = {
      :website_backends => {
        @localhost_website.id => { :publish => "1" },
        @example_com_website.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = PublishedConfig.active_config
    assert_equal(2, active_config.fetch("website_backends").length)
    assert_equal([
      @localhost_website.id,
      @example_com_website.id,
    ].sort, active_config.fetch("website_backends").map { |api| api.fetch("id") }.sort)
  end

  def test_allow_limited_admins_publish_permitted_websites
    config = {
      :website_backends => {
        @localhost_website.id => { :publish => "1" },
      },
    }

    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(localhost_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = PublishedConfig.active_config
    assert_equal(1, active_config.fetch("website_backends").length)
    assert_equal(@localhost_website.id, active_config.fetch("website_backends").first.fetch("id"))
  end

  def test_reject_limited_admins_publish_forbidden_website_backends
    config = {
      :website_backends => {
        @example_com_website.id => { :publish => "1" },
      },
    }

    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(localhost_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({}, PublishedConfig.active_config)
  end

  def test_reject_limited_admins_without_publish_permission
    config = {
      :website_backends => {
        @localhost_website.id => { :publish => "1" },
      },
    }

    unauthorized_localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_manage_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(unauthorized_localhost_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({}, PublishedConfig.active_config)
  end

  def test_reject_limited_admins_without_root_url_permission
    config = {
      :website_backends => {
        @localhost_website.id => { :publish => "1" },
      },
    }

    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token(localhost_admin)).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal({}, PublishedConfig.active_config)
  end
end
