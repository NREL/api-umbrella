require "support/api_umbrella_test_helpers/admin_auth"

module ApiUmbrellaSharedTests
  module Routing
    include ApiUmbrellaTestHelpers::AdminAuth

    def test_website
      response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
      assert_response_code(301, response)
      assert_equal("https://127.0.0.1:9081/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options)
      assert_response_code(200, response)
      assert_match("Your API Site Name", response.body)
    end

    def test_custom_website
      response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_class_id.downcase}-website.foo:9081/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_response_code(200, response)
      assert_match("Test Website Home Page", response.body)
    end

    def test_custom_website_sub_path
      response = Typhoeus.get("http://127.0.0.1:9080/sjkdlfjksdlfj", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_class_id.downcase}-website.foo:9081/sjkdlfjksdlfj", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/sjkdlfjksdlfj", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-website.foo",
        },
      }))
      assert_response_code(404, response)
      assert_match("Test Website 404 Not Found", response.body)
    end

    def test_website_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(200, response)
        if(@assert_default_host)
          assert_match("Test Default Website Home Page", response.body)
        else
          assert_match("Test Website Home Page", response.body)
        end
      else
        assert_response_code(200, response)
        assert_match("Your API Site Name", response.body)
      end
    end

    def test_website_for_host_with_apis_no_website
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_class_id.downcase}-apis-no-website.foo:9081/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(200, response)
        if(@assert_default_host)
          assert_match("Test Default Website Home Page", response.body)
        else
          assert_match("Test Website Home Page", response.body)
        end
      else
        assert_response_code(200, response)
        assert_match("Your API Site Name", response.body)
      end
    end

    def test_gatekeeper_apis
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options.deep_merge(admin_token))
      assert_response_code(200, response)
      assert_equal("application/json", response.headers["content-type"])

      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", http_options.deep_merge(admin_token))
      assert_response_code(200, response)
      assert_equal("application/json", response.headers["content-type"])
    end

    def test_gatekeeper_apis_for_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website || @assert_fallback_website)
        assert_response_code(301, response)
        assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/api-umbrella/v1/state.json", response.headers["Location"])
      else
        assert_response_code(200, response)
        assert_equal("application/json", response.headers["content-type"])
      end

      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/state.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(404, response)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_response_code(200, response)
        assert_equal("application/json", response.headers["content-type"])
      end
    end

    def test_web_app_apis
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/users.json", http_options.deep_merge(admin_token))
      assert_response_code(400, response)
      assert_equal("application/json", response.headers["content-type"])
      assert_match("HTTPS_REQUIRED", response.body)

      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token))
      assert_response_code(200, response)
      assert_equal("application/json; charset=utf-8", response.headers["content-type"])
    end

    def test_web_app_apis_for_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website || @assert_fallback_website)
        assert_response_code(301, response)
        assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/api-umbrella/v1/users.json", response.headers["Location"])
      else
        assert_response_code(400, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("HTTPS_REQUIRED", response.body)
      end

      response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(404, response)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_response_code(200, response)
        assert_equal("application/json; charset=utf-8", response.headers["content-type"])
      end
    end

    def test_configured_apis
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      assert_equal("Hello World", response.body)
    end

    def test_configured_apis_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        assert_equal("Hello World", response.body)
      else
        assert_response_code(301, response)
        assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/#{unique_test_class_id}-api/hello", response.headers["Location"])
      end

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/hello", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        assert_equal("Hello World", response.body)
      else
        assert_response_code(404, response)
        if(@refute_fallback_website)
          assert_equal("application/json", response.headers["content-type"])
          assert_match("NOT_FOUND", response.body)
        elsif(@assert_fallback_website)
          assert_equal("text/plain", response.headers["content-type"])
          assert_match("Test Website 404 Not Found", response.body)
        else
          assert_equal("text/html", response.headers["content-type"])
          assert_match("<center>openresty</center>", response.body)
        end
      end
    end

    def test_prefers_matching_hostname_before_default
      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("apis-no-website.bar", data["headers"]["host"])

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-apis-no-website.foo",
        },
      }))
      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal("apis-no-website.bar", data["headers"]["host"])

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_response_code(404, response)
      end

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_response_code(404, response)
      end

      response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-default.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_response_code(301, response)
        assert_equal("https://#{unique_test_class_id.downcase}-default.foo:9081/#{unique_test_class_id}-api/info/", response.headers["Location"])
      end

      response = Typhoeus.get("https://127.0.0.1:9081/#{unique_test_class_id}-api/info/", http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_class_id}-default.foo",
        },
      }))
      if(@assert_default_host)
        assert_response_code(200, response)
        data = MultiJson.load(response.body)
        assert_equal("default.bar", data["headers"]["host"])
      else
        assert_response_code(404, response)
      end
    end

    def test_admin_ui
      response = Typhoeus.get("http://127.0.0.1:9080/admin/", keyless_http_options)
      assert_response_code(301, response)
      assert_equal("https://127.0.0.1:9081/admin/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/admin/", keyless_http_options)
      assert_response_code(200, response)
      assert_match(%r{<script src="assets/api-umbrella-admin-ui-\w+\.js"}, response.body)
    end

    def test_admin_ui_wildcard_host
      response = Typhoeus.get("http://127.0.0.1:9080/admin/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/admin/", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/admin/", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(404, response)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_response_code(200, response)
        assert_match(%r{<script src="assets/api-umbrella-admin-ui-\w+\.js"}, response.body)
      end
    end

    def test_admin_web_app
      FactoryBot.create(:admin)

      response = Typhoeus.get("http://127.0.0.1:9080/admin/login", keyless_http_options)
      assert_response_code(301, response)
      assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options)
      assert_response_code(200, response)
      assert_match("Admin Sign In", response.body)
    end

    def test_admin_web_app_wildcard_host
      FactoryBot.create(:admin)

      response = Typhoeus.get("http://127.0.0.1:9080/admin/login", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      assert_response_code(301, response)
      assert_equal("https://#{unique_test_id.downcase}-unknown.foo:9081/admin/login", response.headers["Location"])

      response = Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options.deep_merge({
        :headers => {
          "Host" => "#{unique_test_id}-unknown.foo",
        },
      }))
      if(@refute_fallback_website)
        assert_response_code(404, response)
        assert_equal("application/json", response.headers["content-type"])
        assert_match("NOT_FOUND", response.body)
      elsif(@assert_fallback_website)
        assert_response_code(404, response)
        assert_equal("text/plain", response.headers["content-type"])
        if(@assert_default_host)
          assert_match("Test Default Website 404 Not Found", response.body)
        else
          assert_match("Test Website 404 Not Found", response.body)
        end
      else
        assert_response_code(200, response)
        assert_match("Admin Sign In", response.body)
      end
    end
  end
end
