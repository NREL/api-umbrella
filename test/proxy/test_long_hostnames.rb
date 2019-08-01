require_relative "../test_helper"

class Test::Proxy::TestLongHostnames < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_supports_long_hostnames_in_api_backends_without_additional_config
    long_frontend_host = Faker::Lorem.characters(:number => 200)
    long_backend_host = Faker::Lorem.characters(:number => 200)
    assert_equal(200, long_frontend_host.length)
    assert_equal(200, long_backend_host.length)

    prepend_api_backends([
      {
        :frontend_host => long_frontend_host,
        :backend_host => long_backend_host,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
        :headers => {
          "Host" => long_frontend_host,
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(long_backend_host, data["headers"]["host"])
    end
  end

  def test_supports_long_hostnames_in_hosts_with_additional_nginx_config
    long_frontend_host = Faker::Lorem.characters(:number => 200)
    long_backend_host = Faker::Lorem.characters(:number => 200)
    assert_equal(200, long_frontend_host.length)
    assert_equal(200, long_backend_host.length)

    override_config({
      :hosts => [
        {
          :hostname => long_frontend_host,
        },
      ],
      :nginx => {
        :server_names_hash_bucket_size => 200,
      },
    }) do
      prepend_api_backends([
        {
          :frontend_host => long_frontend_host,
          :backend_host => long_backend_host,
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
        },
      ]) do
        response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
          :headers => {
            "Host" => long_frontend_host,
          },
        }))
        assert_response_code(200, response)
        data = MultiJson.load(response.body)
        assert_equal(long_backend_host, data["headers"]["host"])
      end
    end
  end
end
