require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestRedirects < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => unique_test_class_hostname,
          :backend_host => "example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [
            {
              # Add url matches that match the backend (since / will match
              # everything), but don't match the frontend prefix, to ensure
              # these don't get used during rewriting.
              :frontend_prefix => "/unused-matcher-with-root-backend-prefix",
              :backend_prefix => "/",
            },
            {
              :frontend_prefix => "/frontend-prefix-routes-to-path",
              :backend_prefix => "/backend-prefix",
            },
            {
              :frontend_prefix => "/frontend-prefix-routes-to-root/",
              :backend_prefix => "/",
            },
            {
              :frontend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
              :backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/",
            },
            {
              :frontend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/",
              :backend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/backend-piece/",
            },
            {
              :frontend_prefix => "/backend-prefix/redirect",
              :backend_prefix => "/backend-prefix/redirect",
            },
            {
              :frontend_prefix => "/",
              :backend_prefix => "/backend-prefix/",
            },
            {
              :frontend_prefix => "/unused-matcher-with-root-backend-prefix-last",
              :backend_prefix => "/",
            },
          ],
        },
      ])
    end
  end

  def test_relative_unknown_path
    assert_redirects("/somewhere", {
      :frontend_prefix_routes_to_path => "/somewhere",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/somewhere?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/somewhere",
      :frontend_prefix_equals_backend_prefix => "/somewhere",
      :frontend_prefix_contains_backend_prefix => "/somewhere",
      :backend_prefix_contains_frontend_prefix => "/somewhere",
    })
  end

  def test_relative_frontend_prefix_routes_to_root
    assert_redirects("/frontend-prefix-routes-to-root/foo", {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-root/foo",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/foo?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/frontend-prefix-routes-to-root/foo",
      :frontend_prefix_equals_backend_prefix => "/frontend-prefix-routes-to-root/foo",
      :frontend_prefix_contains_backend_prefix => "/frontend-prefix-routes-to-root/foo",
      :backend_prefix_contains_frontend_prefix => "/frontend-prefix-routes-to-root/foo",
    })
  end

  def test_relative_frontend_prefix_routes_to_root_incomplete_path
    assert_redirects("/frontend-prefix-routes-to-roo", {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-roo",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/frontend-prefix-routes-to-roo?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/frontend-prefix-routes-to-roo",
      :frontend_prefix_equals_backend_prefix => "/frontend-prefix-routes-to-roo",
      :frontend_prefix_contains_backend_prefix => "/frontend-prefix-routes-to-roo",
      :backend_prefix_contains_frontend_prefix => "/frontend-prefix-routes-to-roo",
    })
  end

  def test_relative_frontend_prefix_routes_to_path
    assert_redirects("/frontend-prefix-routes-to-path", {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-path",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/frontend-prefix-routes-to-path?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/frontend-prefix-routes-to-path",
      :frontend_prefix_equals_backend_prefix => "/frontend-prefix-routes-to-path",
      :frontend_prefix_contains_backend_prefix => "/frontend-prefix-routes-to-path",
      :backend_prefix_contains_frontend_prefix => "/frontend-prefix-routes-to-path",
    })
  end

  def test_relative_frontend_prefix_contains_backend_prefix_partial
    assert_redirects("/redirect/frontend-prefix-contains-backend-prefix/", {
      :frontend_prefix_routes_to_path => "/redirect/frontend-prefix-contains-backend-prefix/",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/redirect/frontend-prefix-contains-backend-prefix/?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/redirect/frontend-prefix-contains-backend-prefix/",
      :frontend_prefix_equals_backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/",
      :frontend_prefix_contains_backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/?api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/",
    })
  end

  def test_relative_frontend_prefix_contains_backend_prefix_complete
    assert_redirects("/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/", {
      :frontend_prefix_routes_to_path => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
      :frontend_prefix_equals_backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
      :frontend_prefix_contains_backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/?api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
    })
  end

  def test_relative_backend_prefix_contains_frontend_prefix_partial
    assert_redirects("/redirect/backend-prefix-contains-frontend-prefix/", {
      :frontend_prefix_routes_to_path => "/redirect/backend-prefix-contains-frontend-prefix/",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/redirect/backend-prefix-contains-frontend-prefix/?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/redirect/backend-prefix-contains-frontend-prefix/",
      :frontend_prefix_equals_backend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/",
      :frontend_prefix_contains_backend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/",
      :backend_prefix_contains_frontend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/",
    })
  end

  def test_relative_backend_prefix_contains_frontend_prefix_complete
    assert_redirects("/redirect/backend-prefix-contains-frontend-prefix/backend-piece/", {
      :frontend_prefix_routes_to_path => "/redirect/backend-prefix-contains-frontend-prefix/backend-piece/",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/redirect/backend-prefix-contains-frontend-prefix/backend-piece/?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/redirect/backend-prefix-contains-frontend-prefix/backend-piece/",
      :frontend_prefix_equals_backend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/backend-piece/",
      :frontend_prefix_contains_backend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/backend-piece/",
      :backend_prefix_contains_frontend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/?api_key=#{api_key}",
    })
  end

  def test_relative_frontend_prefix_equals_backend_prefix
    assert_redirects("/backend-prefix/more/here", {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-path/more/here?api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/backend-prefix/more/here?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/more/here?api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "/backend-prefix/more/here",
      :frontend_prefix_contains_backend_prefix => "/backend-prefix/more/here",
      :backend_prefix_contains_frontend_prefix => "/backend-prefix/more/here",
    })
  end

  def test_relative_frontend_prefix_equals_backend_prefix_incomplete
    assert_redirects("/backend-prefi", {
      :frontend_prefix_routes_to_path => "/backend-prefi",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/backend-prefi?api_key=#{api_key}",
      :frontend_root_routes_to_path => "/backend-prefi",
      :frontend_prefix_equals_backend_prefix => "/backend-prefi",
      :frontend_prefix_contains_backend_prefix => "/backend-prefi",
      :backend_prefix_contains_frontend_prefix => "/backend-prefi",
    })
  end

  def test_absolute_unknown_host
    assert_redirects("http://other_url.com/hello", {
      :frontend_prefix_routes_to_path => "http://other_url.com/hello",
      :frontend_prefix_routes_to_root => "http://other_url.com/hello",
      :frontend_root_routes_to_path => "http://other_url.com/hello",
      :frontend_prefix_equals_backend_prefix => "http://other_url.com/hello",
      :frontend_prefix_contains_backend_prefix => "http://other_url.com/hello",
      :backend_prefix_contains_frontend_prefix => "http://other_url.com/hello",
    })
  end

  def test_absolute_matching_host
    assert_redirects("http://example.com/hello", {
      :frontend_prefix_routes_to_path => "http://#{unique_test_class_hostname}:9080/hello?api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "http://#{unique_test_class_hostname}:9080/frontend-prefix-routes-to-root/hello?api_key=#{api_key}",
      :frontend_root_routes_to_path => "http://#{unique_test_class_hostname}:9080/hello?api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "http://#{unique_test_class_hostname}:9080/hello?api_key=#{api_key}",
      :frontend_prefix_contains_backend_prefix => "http://#{unique_test_class_hostname}:9080/hello?api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "http://#{unique_test_class_hostname}:9080/hello?api_key=#{api_key}",
    })
  end

  def test_absolute_matching_host_https
    assert_redirects("https://example.com/hello", {
      :frontend_prefix_routes_to_path => "https://#{unique_test_class_hostname}:9081/hello?api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "https://#{unique_test_class_hostname}:9081/frontend-prefix-routes-to-root/hello?api_key=#{api_key}",
      :frontend_root_routes_to_path => "https://#{unique_test_class_hostname}:9081/hello?api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "https://#{unique_test_class_hostname}:9081/hello?api_key=#{api_key}",
      :frontend_prefix_contains_backend_prefix => "https://#{unique_test_class_hostname}:9081/hello?api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "https://#{unique_test_class_hostname}:9081/hello?api_key=#{api_key}",
    })
  end

  def test_absolute_requires_full_domain_match
    assert_redirects("http://eeexample.com/hello", {
      :frontend_prefix_routes_to_path => "http://eeexample.com/hello",
      :frontend_prefix_routes_to_root => "http://eeexample.com/hello",
      :frontend_root_routes_to_path => "http://eeexample.com/hello",
      :frontend_prefix_equals_backend_prefix => "http://eeexample.com/hello",
      :frontend_prefix_contains_backend_prefix => "http://eeexample.com/hello",
      :backend_prefix_contains_frontend_prefix => "http://eeexample.com/hello",
    })
  end

  def test_absolute_rewrites_frontend_prefix_path
    assert_redirects("http://example.com/backend-prefix/", {
      :frontend_prefix_routes_to_path => "http://#{unique_test_class_hostname}:9080/frontend-prefix-routes-to-path/?api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "http://#{unique_test_class_hostname}:9080/frontend-prefix-routes-to-root/backend-prefix/?api_key=#{api_key}",
      :frontend_root_routes_to_path => "http://#{unique_test_class_hostname}:9080/?api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "http://#{unique_test_class_hostname}:9080/backend-prefix/?api_key=#{api_key}",
      :frontend_prefix_contains_backend_prefix => "http://#{unique_test_class_hostname}:9080/backend-prefix/?api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "http://#{unique_test_class_hostname}:9080/backend-prefix/?api_key=#{api_key}",
    })
  end

  def test_relative_unknown_path_leaves_query_params
    assert_redirects("/somewhere?param=example.com", {
      :frontend_prefix_routes_to_path => "/somewhere?param=example.com",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/somewhere?param=example.com&api_key=#{api_key}",
      :frontend_root_routes_to_path => "/somewhere?param=example.com",
      :frontend_prefix_equals_backend_prefix => "/somewhere?param=example.com",
      :frontend_prefix_contains_backend_prefix => "/somewhere?param=example.com",
      :backend_prefix_contains_frontend_prefix => "/somewhere?param=example.com",
    })
  end

  def test_relative_rewrite_keeps_query_params
    assert_redirects("/backend-prefix/more/here?some=param&and=another", {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-path/more/here?some=param&and=another&api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/backend-prefix/more/here?some=param&and=another&api_key=#{api_key}",
      :frontend_root_routes_to_path => "/more/here?some=param&and=another&api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "/backend-prefix/more/here?some=param&and=another",
      :frontend_prefix_contains_backend_prefix => "/backend-prefix/more/here?some=param&and=another",
      :backend_prefix_contains_frontend_prefix => "/backend-prefix/more/here?some=param&and=another",
    })
  end

  def test_absolute_rewrite_keeps_query_params
    assert_redirects("http://example.com/?some=param&and=another", {
      :frontend_prefix_routes_to_path => "http://#{unique_test_class_hostname}:9080/?some=param&and=another&api_key=#{api_key}",
      :frontend_prefix_routes_to_root => "http://#{unique_test_class_hostname}:9080/frontend-prefix-routes-to-root/?some=param&and=another&api_key=#{api_key}",
      :frontend_root_routes_to_path => "http://#{unique_test_class_hostname}:9080/?some=param&and=another&api_key=#{api_key}",
      :frontend_prefix_equals_backend_prefix => "http://#{unique_test_class_hostname}:9080/?some=param&and=another&api_key=#{api_key}",
      :frontend_prefix_contains_backend_prefix => "http://#{unique_test_class_hostname}:9080/?some=param&and=another&api_key=#{api_key}",
      :backend_prefix_contains_frontend_prefix => "http://#{unique_test_class_hostname}:9080/?some=param&and=another&api_key=#{api_key}",
    })
  end

  def test_leaves_empty_redirect
    assert_redirects("", {
      :frontend_prefix_routes_to_path => "",
      :frontend_prefix_routes_to_root => "",
      :frontend_root_routes_to_path => "",
      :frontend_prefix_equals_backend_prefix => "",
      :frontend_prefix_contains_backend_prefix => "",
      :backend_prefix_contains_frontend_prefix => "",
    })
  end

  private

  def make_redirect_request(redirect_to)
    responses = {}

    {
      :frontend_prefix_routes_to_path => "/frontend-prefix-routes-to-path/redirect",
      :frontend_prefix_routes_to_root => "/frontend-prefix-routes-to-root/redirect",
      :frontend_root_routes_to_path => "/redirect",
      :frontend_prefix_equals_backend_prefix => "/backend-prefix/redirect",
      :frontend_prefix_contains_backend_prefix => "/redirect/frontend-prefix-contains-backend-prefix/frontend-piece/",
      :backend_prefix_contains_frontend_prefix => "/redirect/backend-prefix-contains-frontend-prefix/",
    }.each do |key, path|
      response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
        :headers => {
          "Host" => unique_test_class_hostname,
        },
        :params => {
          :to => redirect_to,
        },
      }))
      assert_response_code(302, response)
      responses[key] = response
    end

    responses
  end

  def assert_redirects(redirect_to, expected_redirects)
    responses = make_redirect_request(redirect_to)
    actual_redirects = {}
    responses.each do |key, response|
      actual_redirects[key] = response.headers["Location"]
    end

    assert_equal(expected_redirects, actual_redirects)
  end
end
