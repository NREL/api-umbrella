require_relative "../../test_helper"

class Test::Proxy::Dns::TestDefaultServers < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_static_ipv4
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "localhost",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/ipv4/", :backend_prefix => "/hello/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/ipv4/", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)
    end
  end

  def test_static_ipv6
    skip_unless_ipv6_support

    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "localhost",
        :servers => [{ :host => "::1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/ipv6/", :backend_prefix => "/hello/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/ipv6/", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)
    end
  end

  def test_static_localhost
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "localhost",
        :servers => [{ :host => "localhost", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/localhost/", :backend_prefix => "/hello/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/localhost/", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)
    end
  end

  def test_external_hostname
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "www.google.com",
        :backend_protocol => "https",
        :servers => [{ :host => "www.google.com", :port => 443 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/valid-external-hostname/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/valid-external-hostname/humans.txt", http_options)
      assert_response_code(200, response)
      assert_match("Google is built by a large team", response.body)
    end
  end

  def test_invalid_hostname
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => unique_test_hostname,
        :servers => [{ :host => unique_test_hostname, :port => 90 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/invalid-hostname/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/invalid-hostname/", http_options)
      assert_response_code(503, response)
      assert_match("no healthy upstream", response.body)
    end
  end
end
