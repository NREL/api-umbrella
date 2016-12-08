require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestRedirects < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "frontend.foo",
          :backend_host => "example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/front/end/path", :backend_prefix => "/backend-prefix" }],
        },
      ])
    end
  end

  def test_relative_leaves_unknown_path
    response = make_redirect_request("/somewhere")
    assert_equal("/somewhere", response.headers["location"])
  end

  def test_relative_rewrites_frontend_prefix
    response = make_redirect_request("/backend-prefix/more/here")
    assert_equal("/#{unique_test_class_id}/front/end/path/more/here?api_key=#{api_key}", response.headers["location"])
  end

  def test_absolute_leaves_unknown_domain
    response = make_redirect_request("http://other_url.com/hello")
    assert_equal("http://other_url.com/hello", response.headers["location"])
  end

  def test_absolute_rewrites_backend_domain
    response = make_redirect_request("http://example.com/hello")
    assert_equal("http://frontend.foo/hello?api_key=#{api_key}", response.headers["location"])
  end

  def test_absolute_requires_full_domain_match
    response = make_redirect_request("http://eeexample.com/hello")
    assert_equal("http://eeexample.com/hello", response.headers["location"])
  end

  def test_absolute_rewrites_frontend_prefix_path
    response = make_redirect_request("http://example.com/backend-prefix/")
    assert_equal("http://frontend.foo/#{unique_test_class_id}/front/end/path/?api_key=#{api_key}", response.headers["location"])
  end

  def test_relative_unknown_path_leaves_query_params
    response = make_redirect_request("/somewhere?param=example.com")
    assert_equal("/somewhere?param=example.com", response.headers["location"])
  end

  def test_relative_rewrite_keeps_query_params
    response = make_redirect_request("/backend-prefix/more/here?some=param&and=another")
    assert_equal("/#{unique_test_class_id}/front/end/path/more/here?some=param&and=another&api_key=#{api_key}", response.headers["location"])
  end

  def test_absolute_rewrite_keeps_query_params
    response = make_redirect_request("http://example.com/?some=param&and=another")
    assert_equal("http://frontend.foo/?some=param&and=another&api_key=#{api_key}", response.headers["location"])
  end

  def test_leaves_empty_redirect
    response = make_redirect_request("")
    assert_equal("", response.headers["location"])
  end

  private

  def make_redirect_request(redirect_to)
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/front/end/path/redirect", http_options.deep_merge({
      :headers => {
        "Host" => "frontend.foo",
      },
      :params => {
        :to => redirect_to,
      },
    }))
    assert_response_code(302, response)
    response
  end
end
