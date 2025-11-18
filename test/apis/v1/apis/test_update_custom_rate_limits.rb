require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestUpdateCustomRateLimits < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_updates_embedded_rate_limit_records
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
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
    assert_equal(50, api.settings.rate_limits[0].limit_to)
    assert_equal(10000, api.settings.rate_limits[1].duration)
    assert_equal(75, api.settings.rate_limits[1].limit_to)
  end

  def test_removes_embedded_rate_limit_records
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:custom_rate_limit_api_backend_settings, {
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 5000, :limit_to => 10),
          FactoryBot.build(:rate_limit, :duration => 10000, :limit_to => 20),
        ],
      }),
    })

    attributes = api.as_json
    attributes["settings"]["rate_limits"] = [
      FactoryBot.attributes_for(:rate_limit, :duration => 1000, :limit_to => 5),
    ]

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(5, api.settings.rate_limits[0].limit_to)
  end
end
