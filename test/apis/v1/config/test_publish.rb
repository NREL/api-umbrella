require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPublish < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    Api.delete_all
    WebsiteBackend.delete_all
    ConfigVersion.delete_all
  end

  def after_all
    super
    default_config_version_needed
  end

  def test_publish_with_no_existing_config
    assert_equal(0, ConfigVersion.count)

    api = FactoryBot.create(:api)
    config = {
      :apis => {
        api.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    assert_equal(1, ConfigVersion.count)
    active_config = ConfigVersion.active_config
    assert_equal(1, active_config["apis"].length)
  end

  def test_publish_with_existing_config
    FactoryBot.create(:api)
    ConfigVersion.publish!(ConfigVersion.pending_config)
    assert_equal(1, ConfigVersion.count)

    api = FactoryBot.create(:api)
    config = {
      :apis => {
        api.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    assert_equal(2, ConfigVersion.count)
    active_config = ConfigVersion.active_config
    assert_equal(2, active_config["apis"].length)
  end

  def test_combines_new_and_existing_config_in_order
    api1 = FactoryBot.create(:api, :sort_order => 40)
    api2 = FactoryBot.create(:api, :sort_order => 15)
    ConfigVersion.publish!(ConfigVersion.pending_config)
    assert_equal(1, ConfigVersion.count)

    api3 = FactoryBot.create(:api, :sort_order => 90)
    api4 = FactoryBot.create(:api, :sort_order => 1)
    api5 = FactoryBot.create(:api, :sort_order => 50)
    api6 = FactoryBot.create(:api, :sort_order => 20)

    config = {
      :apis => {
        api3.id => { :publish => "1" },
        api4.id => { :publish => "1" },
        api5.id => { :publish => "1" },
        api6.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = ConfigVersion.active_config
    assert_equal([
      api4.id,
      api2.id,
      api6.id,
      api1.id,
      api5.id,
      api3.id,
    ], active_config["apis"].map { |api| api["_id"] })
  end

  def test_publish_selected_apis_only
    api1 = FactoryBot.create(:api, :name => "Before")
    ConfigVersion.publish!(ConfigVersion.pending_config)

    api1.update(:name => "After")
    api2 = FactoryBot.create(:api)
    api3 = FactoryBot.create(:api)

    config = {
      :apis => {
        api2.id => { :publish => "1" },
        api3.id => { :publish => "0" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = ConfigVersion.active_config
    assert_equal([
      api1.id,
      api2.id,
    ].sort, active_config["apis"].map { |api| api["_id"] }.sort)

    api1_config = active_config["apis"].detect { |api| api["_id"] == api1.id }
    assert_equal("Before", api1_config["name"])
  end

  def test_noop_when_no_changes_selected
    api1 = FactoryBot.create(:api, :name => "Before")
    initial = ConfigVersion.publish!(ConfigVersion.pending_config)
    initial.reload

    api1.update(:name => "After")
    FactoryBot.create(:api)
    FactoryBot.create(:api)

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => {} },
    }))

    assert_response_code(201, response)
    active = ConfigVersion.active
    assert_kind_of(BSON::ObjectId, active.id)
    assert_equal(initial.id, active.id)
    assert_kind_of(Time, active.version)
    assert_equal(initial.version, active.version)
    active_config = active.config
    assert_equal([
      api1.id,
    ].sort, active_config["apis"].map { |api| api["_id"] }.sort)

    api1_config = active_config["apis"].detect { |api| api["_id"] == api1.id }
    assert_equal("Before", api1_config["name"])
  end
end
