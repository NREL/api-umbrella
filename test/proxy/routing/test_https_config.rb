require_relative "../../test_helper"

class Test::Proxy::Routing::TestHttpsConfig < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth

  def setup
    super
    setup_server
  end

  def test_web_app_redirects_to_https_or_errors
    # Check the non-API static web content.
    response = Typhoeus.get("https://127.0.0.1:9081/admin/", keyless_http_options)
    assert_response_code(200, response)
    assert_match(%r{<script src="/admin/assets/api-umbrella-admin-ui-\w+\.js"}, response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/admin/", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/admin/", response.headers["Location"])

    # Check the API pieces of the web app.
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token))
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token))
    assert_response_code(400, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_match("HTTPS_REQUIRED", response.body)

    # Check some of the APIs that have custom settings outside the normal v1
    # URL path.
    response = Typhoeus.get("https://127.0.0.1:9081/admin/stats/logs.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "start" => "0",
        "length" => "10",
      },
    }))
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9080/admin/stats/logs.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        "start_at" => "2015-01-13",
        "end_at" => "2015-01-18",
        "interval" => "day",
        "start" => "0",
        "length" => "10",
      },
    }))
    assert_response_code(400, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_match("HTTPS_REQUIRED", response.body)

    # Test another path that has specific sub-settings
    response = Typhoeus.post("https://127.0.0.1:9081/admin/login", keyless_http_options.deep_merge(admin_session))
    assert_response_code(302, response)
    assert_equal("https://127.0.0.1:9081/admin/#/login", response.headers["Location"])

    response = Typhoeus.post("http://127.0.0.1:9080/admin/login", keyless_http_options.deep_merge(admin_session))
    assert_response_code(400, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_match("HTTPS_REQUIRED", response.body)
  end

  def test_gatekeeper_apis_https_optional
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", http_options)
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options)
    assert_response_code(200, response)
  end

  def test_web_app_host_paths_on_different_host
    http_opts = http_options.deep_merge(admin_token).deep_merge({
      :headers => {
        "Host" => unique_test_hostname,
      },
    })

    # gatekeeper API backends
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", http_opts)
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_opts)
    assert_response_code(200, response)

    # web-app API backends
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_opts)
    assert_response_code(200, response)

    response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/apis.json", http_opts)
    assert_response_code(400, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_match("HTTPS_REQUIRED", response.body)

    override_config({
      "router" => {
        "web_app_host" => "127.0.0.1",
      },
    }) do
      # gatekeeper API backends
      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", http_opts)
      assert_response_code(404, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("NOT_FOUND", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_opts)
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_hostname}:9081/api-umbrella/v1/state.json", response.headers["Location"])

      # web-app API backends
      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_opts)
      assert_response_code(404, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("NOT_FOUND", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/apis.json", http_opts)
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_hostname}:9081/api-umbrella/v1/apis.json", response.headers["Location"])
    end
  end

  def test_custom_website_backend_regex
    response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/", response.headers["Location"])

    response = Typhoeus.get("http://127.0.0.1:9080/website-https-test", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/website-https-test", response.headers["Location"])

    override_config({
      "router" => {
        "website_backend_required_https_regex_default" => "^/website-https-test",
      },
    }) do
      response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
      assert_response_code(200, response)
      assert_match("Your API Site Name", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/website-https-test", keyless_http_options)
      assert_response_code(301, response)
      assert_equal("https://127.0.0.1:9081/website-https-test", response.headers["Location"])
    end
  end

  def test_redirect_not_found_to_https_disabled
    http_opts = keyless_http_options.deep_merge({
      :headers => {
        "Host" => unique_test_hostname,
      },
    })

    response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}", http_opts)
    assert_response_code(404, response)
    assert_equal("text/html", response.headers["content-type"])
    assert_match("<center>openresty</center>", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}", http_opts)
    assert_response_code(301, response)
    assert_equal("https://#{unique_test_hostname}:9081/#{unique_test_id}", response.headers["Location"])

    # We want to test the behavior when the 404 doesn't come from the web app,
    # so disable the web app matching all hosts.
    override_config({
      "router" => {
        "web_app_host" => "127.0.0.1",
      },
    }) do
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}", http_opts)
      assert_response_code(404, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("NOT_FOUND", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}", http_opts)
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_hostname}:9081/#{unique_test_id}", response.headers["Location"])
    end

    override_config({
      "router" => {
        "web_app_host" => "127.0.0.1",
        "redirect_not_found_to_https" => false,
      },
    }) do
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}", http_opts)
      assert_response_code(404, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("NOT_FOUND", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}", http_opts)
      assert_response_code(404, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("NOT_FOUND", response.body)
    end
  end

  def test_custom_api_backend_regex
    # Test behavior when root / path is default website backend.
    response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/", response.headers["Location"])

    response = Typhoeus.get("http://127.0.0.1:9080/hello", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/hello", response.headers["Location"])

    response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options)
    assert_response_code(200, response)
    assert_match("Your API Site Name", response.body)

    override_config({
      "router" => {
        "api_backend_required_https_regex_default" => "^/?$",
      },
    }) do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
        },
      ]) do
        # Verify root is now routing to API backend.
        response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options)
        assert_response_code(403, response)
        assert_match("API_KEY_MISSING", response.body)

        # Check for redirect on root path based on
        # api_backend_required_https_regex_default.
        response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])

        response = Typhoeus.get("http://127.0.0.1:9080", keyless_http_options)
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])

        # Check that redirect regex is based on path only, not including query
        # params (but params are included in regex).
        response = Typhoeus.get("http://127.0.0.1:9080/?foo=bar", keyless_http_options)
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/?foo=bar", response.headers["Location"])

        # Verify that redirect regex is only applied to to root, and ignored
        # for sub paths.
        response = Typhoeus.get("http://127.0.0.1:9080/hello", keyless_http_options)
        assert_response_code(403, response)
        assert_match("API_KEY_MISSING", response.body)

        response = Typhoeus.get("http://127.0.0.1:9080/hello", http_options)
        assert_response_code(200, response)
        assert_equal("Hello World", response.body)
      end
    end
  end

  # This tests the "redirect_https" setting for API backends, which isn't
  # exposed in the web admin, since it's not normally useful for API backends.
  # We mainly have it implemented for routing to the non-API portions of the
  # web-app backend (so we can leverage our normal routing logic for routing to
  # the stylesheets/javascript files too).
  def test_api_backends_forced_to_redirect
    prepend_api_backends([
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/redirect-default/", :backend_prefix => "/" }],
      },
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/redirect-false/", :backend_prefix => "/" }],
        :settings => {
          :redirect_https => false,
        },
      },
      {
        :frontend_host => "127.0.0.1",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/redirect-true/", :backend_prefix => "/" }],
        :settings => {
          :redirect_https => true,
        },
      },
    ]) do
      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/redirect-default/hello", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/redirect-default/hello", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/redirect-false/hello", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/redirect-false/hello", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_id}/redirect-true/hello", http_options)
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_id}/redirect-true/hello", http_options)
      assert_response_code(301, response)
      assert_equal("https://127.0.0.1:9081/#{unique_test_id}/redirect-true/hello", response.headers["Location"])
    end
  end
end
