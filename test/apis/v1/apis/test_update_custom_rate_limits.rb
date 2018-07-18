require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestUpdateCustomRateLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_updates_embedded_rate_limit_records
    api = FactoryBot.create(:api, {
      :settings => FactoryBot.build(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryBot.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryBot.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
        ],
      }),
    })

    attributes = api.as_json
    attributes["settings"]["rate_limits"][0]["limit"] = 50
    attributes["settings"]["rate_limits"][1]["limit"] = 75

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(5000, api.settings.rate_limits[0].duration)
    assert_equal(50, api.settings.rate_limits[0].limit)
    assert_equal(10000, api.settings.rate_limits[1].duration)
    assert_equal(75, api.settings.rate_limits[1].limit)
  end

  def test_removes_embedded_rate_limit_records
    api = FactoryBot.create(:api, {
      :settings => FactoryBot.build(:custom_rate_limit_api_setting, {
        :rate_limits => [
          FactoryBot.attributes_for(:api_rate_limit, :duration => 5000, :limit => 10),
          FactoryBot.attributes_for(:api_rate_limit, :duration => 10000, :limit => 20),
        ],
      }),
    })

    attributes = api.as_json
    attributes["settings"]["rate_limits"] = [
      FactoryBot.attributes_for(:api_rate_limit, :duration => 1000, :limit => 5),
    ]

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(5, api.settings.rate_limits[0].limit)
  end
end
