require_relative "../test_helper"

class Test::Proxy::TestSubSettings < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_sub_settings
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
        :sub_settings => [
          {
            :http_method => "any",
            :regex => "^/info/sub/",
            :settings => {
              :headers => [
                { :key => "X-Sub1", :value => "sub-value1" },
              ],
            },
          },
        ],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/sub/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("sub-value1", data["headers"]["x-sub1"])
    end
  end

  def test_ignores_invalid_sub_settings_without_regex
    prepend_api_backends([
      {
        :name => unique_test_id,
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
        :sub_settings => [
          {
            :http_method => "any",
            :regex => "^/info/sub",
            :settings => {
              :headers => [
                { :key => "X-Sub1", :value => "sub-value1" },
              ],
            },
          },
          {
            :http_method => "any",
            :regex => "^/info/sub/",
            :settings => {
              :headers => [
                { :key => "X-Sub2", :value => "sub-value2" },
              ],
            },
          },
        ],
      },
    ]) do
      force_publish_config do |config|
        api_config = config.fetch("apis").find { |a| a["name"] == unique_test_id }
        api_config.fetch("sub_settings")[0]["regex"] = nil
        config
      end

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/sub/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_nil(data["headers"]["x-sub1"])
      assert_equal("sub-value2", data["headers"]["x-sub2"])
    end
  end
end
