require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPendingChangesAdminPermissionsWebsites < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    Api.delete_all
    WebsiteBackend.delete_all
    ConfigVersion.delete_all

    @localhost_website = FactoryBot.create(:website_backend)
    @example_com_website = FactoryBot.create(:example_com_website_backend)
    ConfigVersion.publish!(ConfigVersion.pending_config)
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_all_websites_for_superuser
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    website_ids = data["config"]["website_backends"]["identical"].map { |website| website["pending"]["_id"] }
    assert_includes(website_ids, @localhost_website.id)
    assert_includes(website_ids, @example_com_website.id)
  end

  def test_permitted_websites_for_limited_admin
    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(localhost_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    website_ids = data["config"]["website_backends"]["identical"].map { |website| website["pending"]["_id"] }
    assert_includes(website_ids, @localhost_website.id)
  end

  def test_excludes_forbidden_websites
    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(localhost_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    website_ids = data["config"]["website_backends"]["identical"].map { |website| website["pending"]["_id"] }
    refute_includes(website_ids, @example_com_website.id)
  end

  def test_exclude_websites_without_publish_permission
    unauthorized_localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:localhost_root_admin_group, :backend_manage_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(unauthorized_localhost_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    website_ids = data["config"]["website_backends"]["identical"].map { |website| website["pending"]["_id"] }
    assert_equal(0, website_ids.length)
  end

  def test_excludes_admins_without_root_url_permissions
    localhost_admin = FactoryBot.create(:limited_admin, :groups => [FactoryBot.create(:google_admin_group, :backend_publish_permission)])
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes.json", http_options.deep_merge(admin_token(localhost_admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    website_ids = data["config"]["website_backends"]["identical"].map { |website| website["pending"]["_id"] }
    assert_equal(0, website_ids.length)
  end
end
