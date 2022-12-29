require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestLiveChanges < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_created_api_keys_can_be_used_immediately
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => FactoryBot.attributes_for(:api_user) },
    }))
    assert_response_code(201, response)
    new_user = MultiJson.load(response.body)

    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => new_user["user"]["api_key"] },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert(new_user["user"]["id"])
    assert_equal(new_user["user"]["id"], data["headers"]["x-api-user-id"])
  end

  def test_detects_role_changes_within_a_few_seconds
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/restricted-info/", :backend_prefix => "/info/" }],
        :settings => { :required_roles => ["restricted"] },
      },
    ]) do
      user = FactoryBot.create(:api_user)

      # Wait a few seconds so we know the initial key created for this test has
      # already been seen by the background task that clears the cache.
      sleep 3.1

      # Ensure that the key works as expected for an initial request.
      response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(user.id, data["headers"]["x-api-user-id"])
      refute(data["headers"]["x-api-roles"])

      # Ensure that the key is rejected from a restricted endpoint.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/restricted-info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_response_code(403, response)

      # Update the key using the API to add the restricted role.
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => { :roles => ["restricted"] }),
      }))
      assert_response_code(200, response)

      # Wait a few seconds to ensure the existing cache for this key get
      # purged.
      sleep 3.1

      # The request to the restricted endpoint should now succeed. If it
      # doesn't, the cache purging may not be working as expected.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/restricted-info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(user.id, data["headers"]["x-api-user-id"])
      assert_equal("restricted", data["headers"]["x-api-roles"])

      # Remove the restricted role (to verify role removal also gets picked up)
      # and ensure that the request goes back to being forbidden.
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => { :roles => [] }),
      }))
      assert_response_code(200, response)

      # Wait a few seconds to ensure the existing cache for this key get
      # purged.
      sleep 3.1

      # Ensure that the key is rejected from a restricted endpoint.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/restricted-info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_response_code(403, response)
    end
  end

  def test_detects_rate_limit_changes_within_a_few_seconds
    user = FactoryBot.create(:api_user)

    # Wait a few seconds so we know the initial key created for this test has
    # already been seen by the background task that clears the cache.
    sleep 3.1

    # Ensure that the key works as expected for an initial request.
    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(user.id, data["headers"]["x-api-user-id"])
    assert_equal("1000", response.headers["x-ratelimit-limit"])

    # Update the key using the API to add the restricted role.
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => {
        :settings => {
          :rate_limit_mode => "custom",
          :rate_limits => [
            FactoryBot.attributes_for(:rate_limit, :limit_to => 10, :response_headers => true),
          ],
        },
      }),
    }))
    assert_response_code(200, response)

    # Wait a few seconds to ensure the existing cache for this key get purged.
    sleep 3.1

    # The request to the restricted endpoint should now succeed. If it
    # doesn't, the cache purging may not be working as expected.
    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(user.id, data["headers"]["x-api-user-id"])
    assert_equal("10", response.headers["x-ratelimit-limit"])
  end
end
