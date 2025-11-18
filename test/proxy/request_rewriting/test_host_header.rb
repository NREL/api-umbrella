require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestHostHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_basic_host_header
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "example.com",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("example.com", data["headers"]["host"])
    end
  end

  def test_host_with_port
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "example.com:8080",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("example.com:8080", data["headers"]["host"])
    end
  end

  def test_backend_host_null
    prepend_api_backends([
      {
        :name => unique_test_id,
        :frontend_host => "127.0.0.1",
        :backend_host => "temporary.example.com",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      force_publish_config do |config|
        api_config = config.fetch("apis").find { |a| a["name"] == unique_test_id }
        api_config["backend_host"] = nil
        config
      end

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("127.0.0.1:9080", data["headers"]["host"])
    end
  end

  def test_backend_host_empty_string
    prepend_api_backends([
      {
        :name => unique_test_id,
        :frontend_host => "127.0.0.1",
        :backend_host => "temporary.example.com",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      force_publish_config do |config|
        api_config = config.fetch("apis").find { |a| a["name"] == unique_test_id }
        api_config["backend_host"] = ""
        config
      end

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options)
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("127.0.0.1:9080", data["headers"]["host"])
    end
  end

  def test_wildcard_basic_host_header
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "example.com",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
        :headers => {
          "Host" => "foobar.example.com",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("example.com", data["headers"]["host"])
    end
  end

  def test_wildcard_host_with_port
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "example.com:8080",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
        :headers => {
          "Host" => "foobar.example.com",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("example.com:8080", data["headers"]["host"])
    end
  end

  def test_wildcard_backend_host_null
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => nil,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
        :headers => {
          "Host" => "foobar.example.com",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("foobar.example.com:9080", data["headers"]["host"])
    end
  end

  def test_wildcard_backend_host_empty_string
    prepend_api_backends([
      {
        :frontend_host => "*",
        :backend_host => "",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/info/", http_options.deep_merge({
        :headers => {
          "Host" => "foobar.example.com",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("foobar.example.com:9080", data["headers"]["host"])
    end
  end
end
