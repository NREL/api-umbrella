require_relative "../../../test_helper"

class Test::Apis::V0::NginxStatus::TestPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    once_per_class_setup do
      override_config_set({
        "nginx" => {
          "vhost_traffic_status" => {
            "enabled" => true,
          },
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_forbids_without_api_key
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v0/nginx-status", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_forbids_api_key_without_role
    user = FactoryBot.create(:api_user, {
      :roles => ["xapi-umbrella-system-info", "api-umbrella-system-infox"],
    })

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v0/nginx-status", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)
  end

  def test_allows_api_key_with_role
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-system-info"],
    })

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v0/nginx-status", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_response_code(200, response)
  end
end
