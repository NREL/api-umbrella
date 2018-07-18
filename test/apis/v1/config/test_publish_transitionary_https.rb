require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestPublishTransitionaryHttps < Minitest::Test
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

  def test_transition_return_error_set_timestamp
    assert_set_timestamp(:transition_return_error)
  end

  ["transition_return_error"].each do |mode|
    define_method("test_#{mode}_set_timestamp") do
      api = FactoryBot.create(:api, {
        :settings => {
          :require_https => mode,
        },
      })
      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_nil(api.settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_kind_of(Time, api.settings.require_https_transition_start_at)
      assert_kind_of(Time, active_config["apis"][0]["settings"]["require_https_transition_start_at"])
    end

    define_method("test_#{mode}_sub_settings_set_timestamp") do
      api = FactoryBot.create(:api, {
        :sub_settings => [
          FactoryBot.attributes_for(:api_sub_setting, {
            :settings_attributes => FactoryBot.attributes_for(:api_setting, {
              :require_https => mode,
            }),
          }),
        ],
      })
      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_nil(api.sub_settings[0].settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_kind_of(Time, api.sub_settings[0].settings.require_https_transition_start_at)
      assert_kind_of(Time, active_config["apis"][0]["sub_settings"][0]["settings"]["require_https_transition_start_at"])
    end

    define_method("test_#{mode}_does_not_touch_existing_timestamp") do
      timestamp = Time.parse("2015-01-16T06:06:28.816Z").utc
      api = FactoryBot.create(:api, {
        :settings => FactoryBot.attributes_for(:api_setting, {
          :require_https => mode,
          :require_https_transition_start_at => timestamp,
        }),
      })
      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_equal(timestamp, api.settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_equal(timestamp, api.settings.require_https_transition_start_at)
      assert_equal(timestamp, active_config["apis"][0]["settings"]["require_https_transition_start_at"])
    end

    define_method("test_#{mode}_mode_changes_without_publishing_does_not_touch_existing_timestamp") do
      timestamp = Time.parse("2015-01-16T06:06:28.816Z").utc
      api = FactoryBot.create(:api, {
        :settings => FactoryBot.attributes_for(:api_setting, {
          :require_https => mode,
          :require_https_transition_start_at => timestamp,
        }),
      })

      api.settings.require_https = "required_return_error"
      api.save!

      api.settings.require_https = "optional"
      api.save!

      api.settings.require_https = nil
      api.save!

      api.settings.require_https = mode
      api.save!

      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_equal(timestamp, api.settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_equal(timestamp, api.settings.require_https_transition_start_at)
      assert_equal(timestamp, active_config["apis"][0]["settings"]["require_https_transition_start_at"])
    end
  end

  ["required_return_error", "optional", nil].each do |mode|
    mode_method_name = mode || mode.inspect

    define_method("test_#{mode_method_name}_unset_timestamp") do
      api = FactoryBot.create(:api, {
        :settings => FactoryBot.attributes_for(:api_setting, {
          :require_https => mode,
          :require_https_transition_start_at => Time.now.utc,
        }),
      })
      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_kind_of(Time, api.settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_nil(api.settings.require_https_transition_start_at)
      assert_nil(active_config["apis"][0]["settings"]["require_https_transition_start_at"])
    end

    define_method("test_#{mode_method_name}_sub_settings_unset_timestamp") do
      api = FactoryBot.create(:api, {
        :sub_settings => [
          FactoryBot.attributes_for(:api_sub_setting, {
            :settings_attributes => FactoryBot.attributes_for(:api_setting, {
              :require_https => mode,
              :require_https_transition_start_at => Time.now.utc,
            }),
          }),
        ],
      })
      config = {
        :apis => {
          api.id => { :publish => "1" },
        },
      }

      assert_kind_of(Time, api.sub_settings[0].settings.require_https_transition_start_at)

      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
        :body => { :config => config },
      }))

      assert_response_code(201, response)
      assert_equal(1, ConfigVersion.count)
      active_config = ConfigVersion.active_config

      api.reload
      assert_nil(api.sub_settings[0].settings.require_https_transition_start_at)
      assert_nil(active_config["apis"][0]["sub_settings"][0]["settings"]["require_https_transition_start_at"])
    end
  end
end
