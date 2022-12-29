require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestLiveChanges < Minitest::Test
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

  def test_detects_published_api_changes_within_a_couple_seconds
    timeout = 2.1

    # Ensure that we hit the default routing.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
    assert_response_code(404, response)

    # Create a new API backend (but don't publish yet).
    api_attributes = FactoryBot.attributes_for(:api_backend, {
      :frontend_host => "127.0.0.1",
      :backend_host => "127.0.0.1",
      :servers => [{ :host => "127.0.0.1", :port => 9444 }],
      :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      :settings => {
        :headers => [
          { :key => "X-New-Api", :value => "test1" },
        ],
      },
    })
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => api_attributes),
    }))
    assert_response_code(201, response)
    new_api = MultiJson.load(response.body)
    assert(new_api["api"]["id"])

    # Wait to ensure time for any backend changes to get picked up.
    sleep timeout

    # Ensure that we still hit the default routing, since we haven't published
    # the new API backend.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
    assert_response_code(404, response)

    # Publish the API backend changes.
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :config => {
          :apis => {
            new_api["api"]["id"] => { :publish => 1 },
          },
        },
      }),
    }))
    assert_response_code(201, response)

    # Wait to ensure time for any backend changes to get picked up.
    response = nil
    Timeout.timeout(timeout) do
      loop do
        response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
        if response.code == 200
          break
        end

        sleep 0.1
      end
    end

    # The request to the new endpoint should now succeed.
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("test1", data["headers"]["x-new-api"])

    # Update the existing API backend.
    api_attributes[:settings][:headers] = [{ :key => "X-Updated-Api", :value => "test2" }]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{new_api["api"]["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => api_attributes),
    }))
    assert_response_code(204, response)

    # Wait to ensure time for any backend changes to get picked up.
    sleep timeout

    # Ensure the updates are not live, since we haven't published them yet.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("test1", data["headers"]["x-new-api"])
    refute(data["headers"]["x-updated-api"])

    # Publish the API backend changes.
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :config => {
          :apis => {
            new_api["api"]["id"] => { :publish => 1 },
          },
        },
      }),
    }))
    assert_response_code(201, response)

    # Wait to ensure time for any backend changes to get picked up.
    response = nil
    Timeout.timeout(timeout) do
      loop do
        response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
        data = MultiJson.load(response.body)
        if response.code == 200 && data["headers"]["x-updated-api"] == "test2"
          break
        end

        sleep 0.1
      end
    end

    # Verify that the updated api backend changes are now live.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("test2", data["headers"]["x-updated-api"])
    refute(data["headers"]["x-new-api"])
  end
end
