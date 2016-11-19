require "support/api_umbrella_test_helpers/admin_auth"

module ApiUmbrellaSharedTests
  module Routing
    include ApiUmbrellaTestHelpers::AdminAuth

    def test_website
      response = Typhoeus.get("http://127.0.0.1:9080/", http_options.except(:headers))
      assert_equal(200, response.code, response.body)
      assert_match("Your API Site Name", response.body)
    end

    def test_custom_website
      response = Typhoeus.get("http://127.0.0.1:9080/", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_equal(200, response.code, response.body)
      assert_match("Test Website Home Page", response.body)
    end

    def test_custom_website_sub_path
      response = Typhoeus.get("http://127.0.0.1:9080/sjkdlfjksdlfj", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_equal(404, response.code, response.body)
      assert_match("Test Website 404 Not Found", response.body)
    end

    def test_website_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(200, response.code, response.body)
        if(@assert_default_host)
          assert_match("Test Default Website Home Page", response.body)
        else
          assert_match("Test Website Home Page", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_match("Your API Site Name", response.body)
      end
    end

    def test_website_for_host_with_apis_no_website
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_equal(200, response.code, response.body)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(200, response.code, response.body)
        if(@assert_default_host)
          assert_match("Test Default Website Home Page", response.body)
        else
          assert_match("Test Website Home Page", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_match("Your API Site Name", response.body)
      end
    end

    def test_gatekeeper_apis
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options.deep_merge(admin_token))
      assert_equal(200, response.code, response.body)
      assert_equal("application/json", response.headers["content-type"])
    end

    def test_gatekeeper_apis_for_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
      end
    end

    def test_web_app_apis
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/users.json", http_options.deep_merge(admin_token))
      assert_equal(200, response.code, response.body)
      assert_equal("application/json; charset=utf-8", response.headers["content-type"])
    end

    def test_web_app_apis_for_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_equal("application/json; charset=utf-8", response.headers["content-type"])
      end
    end

    def test_configured_apis
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_equal(200, response.code, response.body)
      assert_equal("Hello World", response.body)
    end

    def test_configured_apis_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_equal(200, response.code, response.body)
        assert_equal("Hello World", response.body)
      else
        assert_equal(404, response.code, response.body)
        if(@refute_fallback_website)
          assert_equal("application/json", response.headers["content-type"])
          assert_match("NOT_FOUND", response.body)
        elsif(@assert_fallback_website)
          assert_equal("text/plain", response.headers["content-type"])
          assert_match("Test Website 404 Not Found", response.body)
        else
          assert_equal("text/html", response.headers["content-type"])
          assert_match("nginx", response.body)
        end
      end
    end

    def test_prefers_matching_hostname_before_default
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal("apis-no-website.bar", data["headers"]["host"])

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_equal(200, response.code, response.body)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_equal(404, response.code, response.body)
      end

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-default.foo",
        },
      }))
      if(@assert_default_host)
        assert_equal(200, response.code, response.body)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_equal(404, response.code, response.body)
      end
    end

    def test_admin_ui
      response = Typhoeus.get("https://127.0.0.1:9081/admin/", http_options.except(:headers))
      assert_equal(200, response.code, response.body)
      assert_match('<script src="assets/api-umbrella-admin-ui.js">', response.body)
    end

    def test_admin_ui_wildcard_host
      response = Typhoeus.get("https://127.0.0.1:9081/admin/", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_match('<script src="assets/api-umbrella-admin-ui.js">', response.body)
      end
    end

    def test_admin_web_app
      response = Typhoeus.get("https://127.0.0.1:9081/admin/login", http_options.except(:headers))
      assert_equal(200, response.code, response.body)
      assert_match("Admin Login", response.body)
    end

    def test_admin_web_app_wildcard_host
      response = Typhoeus.get("https://127.0.0.1:9081/admin/login", http_options.except(:headers).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_equal(404, response.code, response.body)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_equal(200, response.code, response.body)
        assert_match("Admin Login", response.body)
      end
    end
  end
end
