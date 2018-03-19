require_relative "../../test_helper"

class Test::Proxy::Routing::TestHttpsConfig < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::AdminAuth
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "router" => {
          "web_app_backend_required_https_regex" => "^/admin/web-app-https-test",
          "website_backend_required_https_regex_default" => "^/website-https-test",
          "redirect_not_found_to_https" => false,
          "web_app_host" => "127.0.0.1",
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_custom_web_app_regex
    response = Typhoeus.get("http://127.0.0.1:9080/admin/", keyless_http_options)
    assert_response_code(200, response)
    assert_match(%r{<script src="assets/api-umbrella-admin-ui-\w+\.js"}, response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/admin/web-app-https-test", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/admin/web-app-https-test", response.headers["Location"])
  end

  def test_custom_website_backend_regex
    response = Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options)
    assert_response_code(200, response)
    assert_match("Your API Site Name", response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/website-https-test", keyless_http_options)
    assert_response_code(301, response)
    assert_equal("https://127.0.0.1:9081/website-https-test", response.headers["Location"])
  end

  def test_not_found_https_disabled
    response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/state.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => {
        "Host" => "#{unique_test_id}-unknown.foo",
      },
    }))
    assert_response_code(404, response)
    assert_equal("application/json", response.headers["content-type"])
    assert_match("NOT_FOUND", response.body)
  end
end
