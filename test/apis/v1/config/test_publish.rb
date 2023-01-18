require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPublish < Minitest::Test
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

  def test_publish_with_no_existing_config
    assert_equal(1, PublishedConfig.count)

    api = FactoryBot.create(:api_backend)
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
    assert_equal(2, PublishedConfig.count)
    active_config = PublishedConfig.active_config
    assert_equal(1, active_config["apis"].length)
  end

  def test_publish_with_existing_config
    api = FactoryBot.create(:api_backend)
    publish_api_backends([api.id])
    assert_equal(2, PublishedConfig.count)

    api = FactoryBot.create(:api_backend)
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
    assert_equal(3, PublishedConfig.count)
    active_config = PublishedConfig.active_config
    assert_equal(2, active_config["apis"].length)
  end

  def test_combines_new_and_existing_config_in_created_order
    api1 = FactoryBot.create(:api_backend, :created_order => 4)
    api2 = FactoryBot.create(:api_backend, :created_order => 2)
    api3 = FactoryBot.create(:api_backend, :created_order => 6)
    api4 = FactoryBot.create(:api_backend, :created_order => 1)
    api5 = FactoryBot.create(:api_backend, :created_order => 5)
    api6 = FactoryBot.create(:api_backend, :created_order => 3)

    publish_api_backends([api3.id, api1.id])
    assert_equal(2, PublishedConfig.count)
    active_config = PublishedConfig.active_config
    assert_equal([
      api1.id,
      api3.id,
    ], active_config["apis"].map { |api| api["id"] })

    config = {
      :apis => {
        api6.id => { :publish => "1" },
        api2.id => { :publish => "1" },
        api3.id => { :publish => "1" },
        api4.id => { :publish => "1" },
        api5.id => { :publish => "1" },
      },
    }

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => config },
    }))

    assert_response_code(201, response)
    active_config = PublishedConfig.active_config
    assert_equal([
      api4.id,
      api2.id,
      api6.id,
      api1.id,
      api5.id,
      api3.id,
    ], active_config["apis"].map { |api| api["id"] })
  end

  def test_publish_selected_apis_only
    api1 = FactoryBot.create(:api_backend, :name => "Before")
    publish_api_backends([api1.id])

    api1.update(:name => "After")
    api2 = FactoryBot.create(:api_backend)
    api3 = FactoryBot.create(:api_backend)

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
    active_config = PublishedConfig.active_config
    assert_equal([
      api1.id,
      api2.id,
    ].sort, active_config["apis"].map { |api| api["id"] }.sort)

    api1_config = active_config["apis"].detect { |api| api["id"] == api1.id }
    assert_equal("Before", api1_config["name"])
  end

  def test_noop_when_no_changes_selected
    api1 = FactoryBot.create(:api_backend, :name => "Before")
    publish_api_backends([api1.id])
    initial = PublishedConfig.active

    api1.update(:name => "After")
    FactoryBot.create(:api_backend)
    FactoryBot.create(:api_backend)

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :config => {} },
    }))

    assert_response_code(201, response)
    active = PublishedConfig.active
    assert_kind_of(Integer, active.id)
    assert_equal(initial.id, active.id)
    active_config = active.config
    assert_equal([
      api1.id,
    ].sort, active_config["apis"].map { |api| api["id"] }.sort)

    api1_config = active_config["apis"].detect { |api| api["id"] == api1.id }
    assert_equal("Before", api1_config["name"])
  end
end
