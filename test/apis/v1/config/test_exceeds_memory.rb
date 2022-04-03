require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestExceedsMemory < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::ExerciseAllWorkers
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    publish_default_config_version
    once_per_class_setup do
      override_config_set({
        :nginx => {
          :shared_dicts => {
            :active_config => {
              :size => "32k",
            },
          },
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
    publish_default_config_version
  end

  def test_retains_previous_config_when_new_config_exceeds_memory
    log_tail = LogTail.new("nginx/current")

    # Ensure that the config is unpublished.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/initial/0/info/", http_options)
    assert_response_code(404, response)
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/initial/1/info/", http_options)
    assert_response_code(404, response)
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/0/info/", http_options)
    assert_response_code(404, response)
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/1/info/", http_options)
    assert_response_code(404, response)

    # Create a new API backend.
    api_ids = Array.new(2) do |i|
      create_api("/#{unique_test_id}/initial/#{i}/")
    end

    # Publish the API backend changes.
    publish_api_ids(api_ids)
    config_initial = PublishedConfig.active
    config_initial.wait_until_live

    # No errors should have occurred during publishing
    log_output = log_tail.read
    refute_match("failed to set 'packed_data' in 'active_config' shared dict", log_output)

    # Requests to the new APIs should now succeed.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/initial/0/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    10.times do |i|
      assert_equal(250, data["headers"]["x-new-api#{i}"].bytesize)
    end
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/initial/1/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    10.times do |i|
      assert_equal(250, data["headers"]["x-new-api#{i}"].bytesize)
    end

    # Requests to the next set of config should still not succeed.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/0/info/", http_options)
    assert_response_code(404, response)
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/1/info/", http_options)
    assert_response_code(404, response)

    # Create enough new API backends to exceed the available "active_config"
    # shdict size.
    api_ids = Array.new(20) do |i|
      create_api("/#{unique_test_id}/too-big/#{i}/")
    end

    # Publish the API backend changes (which are too big to fit in memory).
    publish_api_ids(api_ids)
    config_too_big = PublishedConfig.active

    # The config version will never get published, so instead of
    # `wait_until_live` on the published config, wait until we find an
    # indicator of the failure in the logs.
    log_output = log_tail.read_until(/Reverted active_config back to previous version after setting new version failed/)

    # Ensure that a new configuration version was at least attempted to be
    # published (even though it was too big to successfully publish).
    refute_equal(config_initial.id, config_too_big.id)

    # Verify that an error was printed to the log about being out of memory.
    assert_match(/\[error\].*Error setting active_config.*no memory/, log_output)

    # Verify that the configuration was rolled back and the original APIs are
    # still accessible. Check all workers to ensure no local caching is playing
    # a role.
    responses = exercise_all_workers("/#{unique_test_id}/initial/0/info/", http_options)
    responses.each do |resp|
      assert_response_code(200, resp)
      data = MultiJson.load(resp.body)
      10.times do |i|
        assert_equal(250, data["headers"]["x-new-api#{i}"].bytesize)
      end
    end

    # Sleep for a little while to ensure there are no lingering caching or
    # processing going on, and then check all workers again on the other
    # original API.
    sleep 1.6
    responses = exercise_all_workers("/#{unique_test_id}/initial/1/info/", http_options)
    responses.each do |resp|
      assert_response_code(200, resp)
      data = MultiJson.load(resp.body)
      10.times do |i|
        assert_equal(250, data["headers"]["x-new-api#{i}"].bytesize)
      end
    end

    # The new API backends (that were too big to fit into memory) should still
    # fail, since there wasn't enough memory to successfully publish them.
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/0/info/", http_options)
    assert_response_code(404, response)
    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/too-big/1/info/", http_options)
    assert_response_code(404, response)
  end

  private

  def create_api(frontend_prefix)
    # Add some large headers so each API backend will take up more memory.
    headers = []
    10.times do |i|
      headers << { :key => "X-New-Api#{i}", :value => SecureRandom.hex(125) }
    end

    api_attributes = FactoryBot.attributes_for(:api_backend, {
      :frontend_host => "127.0.0.1",
      :backend_host => "127.0.0.1",
      :servers => [{ :host => "127.0.0.1", :port => 9444 }],
      :url_matches => [{ :frontend_prefix => frontend_prefix, :backend_prefix => "/" }],
      :settings => {
        :headers => headers,
      },
    })
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => api_attributes),
    }))
    assert_response_code(201, response)
    api = MultiJson.load(response.body)
    assert(api["api"]["id"])

    api["api"]["id"]
  end

  def publish_api_ids(api_ids)
    publish_config = { :apis => {} }
    api_ids.each do |api_id|
      publish_config[:apis][api_id] = { :publish => 1 }
    end

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :config => publish_config,
      }),
    }))
    assert_response_code(201, response)
  end
end
