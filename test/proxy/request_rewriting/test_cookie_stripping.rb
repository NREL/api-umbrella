require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestCookieStripping < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_removes_cookie_when_only_single_analytics_present
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "__utma=foo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute(data["headers"]["cookie"])
  end

  def test_removes_cookie_when_only_multiple_analytics_present
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "__utma=foo; __utmz=bar; _ga=foo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute(data["headers"]["cookie"])
  end

  def test_removes_only_analytics_cookies
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "__utma=foo; moo=boo; __utmz=bar; foo=bar; _ga=foo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("moo=boo; foo=bar", data["headers"]["cookie"])
  end

  def test_parses_cookies_with_variable_whitespace
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "__utma=foo;moo=boo;    __utmz=bar;    foo=bar;_ga=foo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("moo=boo; foo=bar", data["headers"]["cookie"])
  end

  def test_removes_cookies_case_insensitively
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "__UtMA=foo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute(data["headers"]["cookie"])
  end

  def test_leaves_cookie_alone_without_analytics
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "foo=bar; moo=boo",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo=bar; moo=boo", data["headers"]["cookie"])
  end

  def test_strips_admin_session_cookie
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "foo1=bar1; _api_umbrella_session=foo; foo2=bar2",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo1=bar1; foo2=bar2", data["headers"]["cookie"])
  end

  def test_strips_admin_csrf_token_cookie
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "foo1=bar1; _api_umbrella_csrf_token=foo; foo2=bar2",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo1=bar1; foo2=bar2", data["headers"]["cookie"])
  end

  def test_leave_admin_session_cookie_with_mixed_calls
    # Call a non-web backend first (to ensure it doesn't persist the list of
    # cookies to strip).
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => {
        "Cookie" => "foo1=bar1; _api_umbrella_session=foo; foo2=bar2",
      },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo1=bar1; foo2=bar2", data["headers"]["cookie"])

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/analytics/drilldown.json", http_options.deep_merge(admin_session).deep_merge({
      :params => {
        :search => "",
        :start_at => "2015-01-13",
        :end_at => "2015-01-18",
        :interval => "day",
        :prefix => "0/",
      },
    }))
    assert_response_code(200, response)
  end
end
