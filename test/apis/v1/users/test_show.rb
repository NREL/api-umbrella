require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestShow < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_user_response
    user = FactoryBot.create(:api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal([
      "user",
    ], data.keys.sort)

    expected_keys = [
      "api_key",
      "api_key_hides_at",
      "api_key_preview",
      "created_at",
      "created_by",
      "creator",
      "deleted_at",
      "disabled_at",
      "email",
      "email_verified",
      "enabled",
      "first_name",
      "id",
      "last_name",
      "metadata",
      "metadata_yaml_string",
      "registration_ip",
      "registration_origin",
      "registration_referer",
      "registration_source",
      "registration_user_agent",
      "roles",
      "settings",
      "throttle_by_ip",
      "ts",
      "updated_at",
      "updated_by",
      "updater",
      "use_description",
      "version",
      "website",
    ]

    assert_equal(expected_keys.sort, data["user"].keys.sort)
  end

  def test_embedded_rate_limit_response
    user = FactoryBot.create(:custom_rate_limit_api_user)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    data = MultiJson.load(response.body)
    assert_equal(1, data["user"]["settings"]["rate_limits"].length)
    rate_limit = data["user"]["settings"]["rate_limits"].first
    assert_equal([
      "id",
      # Legacy _id field we never meant to return (everything else returns
      # just "id"), but we accidentally did in this embedded case. Keep
      # returning for backwards compatibility, but should remove for V2 of
      # APIs.
      "_id",
      "accuracy",
      "distributed",
      "duration",
      "limit",
      "limit_by",
      "response_headers",
    ].sort, rate_limit.keys.sort)
    assert_match(/\A[0-9a-f-]{36}\z/, rate_limit["id"])
    assert_equal(rate_limit["id"], rate_limit["_id"])
    assert_nil(rate_limit.fetch("accuracy"))
    assert_equal(true, rate_limit["distributed"])
    assert_equal(60000, rate_limit["duration"])
    assert_equal(500, rate_limit["limit"])
    assert_equal("ip", rate_limit["limit_by"])
    assert_equal(true, rate_limit["response_headers"])
  end
end
