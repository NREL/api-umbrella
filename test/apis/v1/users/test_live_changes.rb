require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestLiveChanges < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_created_api_keys_can_be_used_immediately
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => FactoryGirl.attributes_for(:api_user) },
    }))
    assert_equal(201, response.code, response.body)
    new_user = MultiJson.load(response.body)

    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => new_user["user"]["api_key"] },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert(new_user["user"]["id"])
    assert_equal(new_user["user"]["id"], data["headers"]["x-api-user-id"])
  end

  def test_detects_role_changes_within_2_seconds
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/restricted-info/", :backend_prefix => "/info/" }],
        :settings => { :required_roles => ["restricted"] },
      },
    ]) do
      user = FactoryGirl.create(:api_user)

      # Wait 2 seconds so we know the initial key created for this test has
      # already been seen by the background task that clears the cache.
      sleep 2.1

      # Ensure that the key works as expected for an initial request.
      response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal(user.id, data["headers"]["x-api-user-id"])
      refute(data["headers"]["x-api-roles"])

      # Ensure that the key is rejected from a restricted endpoint.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/restricted-info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_equal(403, response.code, response.body)

      # Update the key using the API to add the restricted role.
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:user => { :roles => ["restricted"] }),
      }))
      assert_equal(200, response.code, response.body)

      # Wait 2 seconds to ensure the existing cache for this key get purged.
      sleep 2.1

      # The request to the restricted endpoint should now succeed. If it
      # doesn't, the cache purging may not be working as expected.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/restricted-info/", http_options.deep_merge({
        :headers => { "X-Api-Key" => user.api_key },
      }))
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal(user.id, data["headers"]["x-api-user-id"])
      assert_equal("restricted", data["headers"]["x-api-roles"])
    end
  end

  def test_detects_rate_limit_changes_within_2_seconds
    user = FactoryGirl.create(:api_user)

    # Wait 2 seconds so we know the initial key created for this test has
    # already been seen by the background task that clears the cache.
    sleep 2.1

    # Ensure that the key works as expected for an initial request.
    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_equal(200, response.code, response.body)
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
            FactoryGirl.attributes_for(:api_rate_limit, :limit => 10, :response_headers => true),
          ],
        },
      }),
    }))
    assert_equal(200, response.code, response.body)

    # Wait 2 seconds to ensure the existing cache for this key get purged.
    sleep 2.1

    # The request to the restricted endpoint should now succeed. If it
    # doesn't, the cache purging may not be working as expected.
    response = Typhoeus.get("https://127.0.0.1:9081/api/info/", http_options.deep_merge({
      :headers => { "X-Api-Key" => user.api_key },
    }))
    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_equal(user.id, data["headers"]["x-api-user-id"])
    assert_equal("10", response.headers["x-ratelimit-limit"])
  end
end
