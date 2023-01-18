require_relative "../test_helper"

class Test::Proxy::TestNginxRewrites < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_basic_rewrites
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "default.foo",
          "default" => true,
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite/(debian|el|ubuntu)/([\\d\\.]+)/(file[_-]([\\d\\.]+)-\\d+).*((\\.|_)(amd64|x86_64).(deb|rpm)) https://example.com/downloads/v$4/$3.$1$2$5? redirect",
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
        {
          "hostname" => "known.foo",
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Basic rewrite
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options)
      assert_response_code(301, response)
      assert_equal("https://example.com/something/?foo=bar", response.headers["location"])

      # Advanced with replacements rewrite
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite/el/7/file-0.6.0-1.el7.x86_64.rpm?foo=bar", http_options)
      assert_response_code(302, response)
      assert_equal("https://example.com/downloads/v0.6.0/file-0.6.0-1.el7.x86_64.rpm", response.headers["location"])
    end
  end

  def test_default_host
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "default.foo",
          "default" => true,
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
        {
          "hostname" => "known.foo",
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "default.foo" },
      }))
      assert_response_code(301, response)
      assert_equal("https://example.com/something/?foo=bar", response.headers["location"])

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "known.foo" },
      }))
      assert_response_code(404, response)

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(301, response)
      assert_equal("https://example.com/something/?foo=bar", response.headers["location"])
    end
  end

  def test_no_default_host
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "default.foo",
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "default.foo" },
      }))
      assert_response_code(301, response)
      assert_equal("https://example.com/something/?foo=bar", response.headers["location"])

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(404, response)
    end
  end

  # When nginx has no default_server defined, then the first server defined
  # becomes the default one. So test to see how this ordering also interacts
  # with a wildcard host.
  def test_no_default_host_wildcard_first
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "*",
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
        {
          "hostname" => "known.foo",
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "known.foo" },
      }))
      assert_response_code(404, response)

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(404, response)
    end
  end

  def test_no_default_host_wildcard_last
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "known.foo",
        },
        {
          "hostname" => "*",
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "known.foo" },
      }))
      assert_response_code(404, response)

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(404, response)
    end
  end

  def test_wildcard_is_default
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "*",
          "default" => true,
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
        {
          "hostname" => "known.foo",
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "known.foo" },
      }))
      assert_response_code(404, response)

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(301, response)
      assert_equal("https://example.com/something/?foo=bar", response.headers["location"])
    end
  end

  def test_wildcard_is_not_default
    log_tail = LogTail.new("nginx/current")
    override_config({
      "hosts" => [
        {
          "hostname" => "*",
          "rewrites" => [
            "^/#{unique_test_id}/hello/rewrite https://example.com/something/ permanent",
          ],
        },
        {
          "hostname" => "known.foo",
          "default" => true,
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      # Known host without rewrites
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "known.foo" },
      }))
      assert_response_code(404, response)

      # Unknown host
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/hello/rewrite?foo=bar", http_options.deep_merge({
        :headers => { "Host" => "unknown.foo" },
      }))
      assert_response_code(404, response)
    end
  end

  def test_precedence
    log_tail = LogTail.new("nginx/current")
    override_config({
      "apis" => [
        {
          "frontend_host" => "with-apis-and-website.foo",
          "backend_host" => "127.0.0.1",
          "servers" => [{ "host" => "127.0.0.1", "port" => 9444 }],
          "url_matches" => [{ "frontend_prefix" => "/#{unique_test_id}/api-example/", "backend_prefix" => "/hello/" }],
        },
      ],
      "website_backends" => [
        {
          "frontend_host" => "with-apis-and-website.foo",
          "server_host" => "127.0.0.1",
          "server_port" => 9444,
        },
      ],
      "hosts" => [
        {
          "hostname" => "with-apis-and-website.foo",
          "default" => true,
          "rewrites" => [
            "^/#{unique_test_id}/api-example/rewrite_me$ https://example.com/ permanent",
            "^/#{unique_test_id}/website-example/rewrite_me$ https://2.example.com/ permanent",
            "^/admin/rewrite_me$ https://3.example.com/ permanent",
            "^/admin/login/rewrite_me$ https://4.example.com/ permanent",
          ],
        },
      ],
    }) do
      refute_nginx_duplicate_server_name_warnings(log_tail)

      http_opts = http_options.deep_merge({
        :headers => { "Host" => "with-apis-and-website.foo" },
      })

      # Rewrites match before API Backends.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/api-example/rewrite_me", http_opts)
      assert_response_code(301, response)
      assert_equal("https://example.com/", response.headers["location"])
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/api-example/rewrite_me_just_kidding", http_opts)
      assert_response_code(200, response)
      assert_match("Hello World", response.body)

      # Rewrites match before Website Backends.
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/website-example/rewrite_me", http_opts)
      assert_response_code(301, response)
      assert_equal("https://2.example.com/", response.headers["location"])
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/website-example/rewrite_me_just_kidding", http_opts)
      assert_response_code(404, response)
      assert_match("Test 404 Not Found", response.body)

      # Rewrites match before the admin tool's static content.
      response = Typhoeus.get("https://127.0.0.1:9081/admin/rewrite_me", http_opts)
      assert_response_code(301, response)
      assert_equal("https://3.example.com/", response.headers["location"])
      response = Typhoeus.get("https://127.0.0.1:9081/admin/rewrite_me_just_kidding", http_opts)
      assert_response_code(404, response)
      assert_match("<center>API Umbrella</center>", response.body)

      # Rewrites match before the admin tool's dynamic app.
      response = Typhoeus.get("https://127.0.0.1:9081/admin/login/rewrite_me", http_opts)
      assert_response_code(301, response)
      assert_equal("https://4.example.com/", response.headers["location"])
      response = Typhoeus.get("https://127.0.0.1:9081/admin/login/rewrite_me_just_kidding", http_opts)
      assert_response_code(404, response)
      assert_match("<center>API Umbrella</center>", response.body)
    end
  end

  private

  def refute_nginx_duplicate_server_name_warnings(log_tail)
    log_output = log_tail.read
    assert_match(/\[notice\].*: reconfiguring/, log_output)
    refute_match("conflicting server name", log_output)
    refute_match("warn", log_output)
  end
end
