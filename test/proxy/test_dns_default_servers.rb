require_relative "../test_helper"

class TestProxyDnsDefaultServers < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
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
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/ipv4/", self.http_options)
      assert_equal(200, response.code, response.body)
      assert_equal("Hello World", response.body)
    end
  end

  def test_static_ipv6
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "localhost",
        :servers => [{ :host => "::1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/ipv6/", :backend_prefix => "/hello/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/ipv6/", self.http_options)
      assert_equal(200, response.code, response.body)
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
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/localhost/", self.http_options)
      assert_equal(200, response.code, response.body)
      assert_equal("Hello World", response.body)
    end
  end

  def test_external_hostname
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "www.google.com",
        :servers => [{ :host => "www.google.com", :port => 80 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/valid-external-hostname/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/valid-external-hostname/humans.txt", self.http_options)
      assert_equal(200, response.code, response.body)
      assert_match("Google is built by a large team", response.body)
    end
  end

  def test_invalid_hostname
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "invalid.ooga",
        :servers => [{ :host => "invalid.ooga", :port => 90 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/invalid-hostname/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/invalid-hostname/", self.http_options)
      assert_equal(502, response.code, response.body)
    end
  end
end
