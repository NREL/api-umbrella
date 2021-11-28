require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestHostWildcardSubdomains < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "*.star-dot.#{unique_test_class_id}",
          :backend_host => "example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "wildcard-star-dot" },
            ],
          },
        },
        {
          :frontend_host => "*.star-dot-backend.#{unique_test_class_id}",
          :backend_host => "*.example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "wildcard-star-dot-backend" },
            ],
          },
        },
        {
          :frontend_host => ".dot.#{unique_test_class_id}",
          :backend_host => "example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "wildcard-dot" },
            ],
          },
        },
        {
          :frontend_host => ".dot-backend.#{unique_test_class_id}",
          :backend_host => ".example.com",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "wildcard-dot-backend" },
            ],
          },
        },
      ])
    end
  end

  def test_star_dot_matches_wildcard_subdomains
    response = make_request_to_host("foo.star-dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot", response)

    response = make_request_to_host("bar.star-dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot", response)
  end

  def test_star_dot_matches_multi_level_subdomains
    response = make_request_to_host("foo.bar.star-dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot", response)
  end

  def test_star_dot_does_not_match_root_domain
    response = make_request_to_host("star-dot.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_star_dot_does_not_match_wildcards_without_dot_boundary
    response = make_request_to_host("foostar-dot.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_star_dot_does_not_match_domains_with_text_suffix
    response = make_request_to_host("foo.star-dot.#{unique_test_class_id}bar", "/info/")
    assert_response_code(404, response)
  end

  def test_star_dot_matches_wildcard_with_port_suffix
    response = make_request_to_host("foo.star-dot.#{unique_test_class_id}:80", "/info/")
    assert_backend_match("wildcard-star-dot", response)
  end

  def test_star_dot_static_backend_host
    response = make_request_to_host("foo.star-dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot", response)
    data = MultiJson.load(response.body)
    assert_equal("example.com", data["headers"]["host"])
  end

  def test_star_dot_wildcard_backend_host
    response = make_request_to_host("foo.star-dot-backend.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot-backend", response)
    data = MultiJson.load(response.body)
    assert_equal("foo.example.com", data["headers"]["host"])

    response = make_request_to_host("foo.bar.star-dot-backend.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot-backend", response)
    data = MultiJson.load(response.body)
    assert_equal("foo.bar.example.com", data["headers"]["host"])
  end

  def test_dot_matches_wildcard_subdomains
    response = make_request_to_host("foo.dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)

    response = make_request_to_host("bar.dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)
  end

  def test_dot_matches_multi_level_subdomains
    response = make_request_to_host("foo.bar.dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)
  end

  def test_dot_matches_root_domain
    response = make_request_to_host("dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)
  end

  def test_dot_does_not_match_wildcards_without_dot_boundary
    response = make_request_to_host("foodot.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_dot_does_not_match_domains_with_text_suffix
    response = make_request_to_host("foo.dot.#{unique_test_class_id}bar", "/info/")
    assert_response_code(404, response)
  end

  def test_dot_matches_wildcard_with_port_suffix
    response = make_request_to_host("foo.dot.#{unique_test_class_id}:80", "/info/")
    assert_backend_match("wildcard-dot", response)
  end

  def test_dot_static_backend_host
    response = make_request_to_host("foo.dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)
    data = MultiJson.load(response.body)
    assert_equal("example.com", data["headers"]["host"])
  end

  def test_dot_wildcard_backend_host
    response = make_request_to_host("foo.dot-backend.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot-backend", response)
    data = MultiJson.load(response.body)
    assert_equal("foo.example.com", data["headers"]["host"])

    response = make_request_to_host("foo.bar.dot-backend.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot-backend", response)
    data = MultiJson.load(response.body)
    assert_equal("foo.bar.example.com", data["headers"]["host"])
  end

  def test_star_does_not_match_wildcard_subdomains
    response = make_request_to_host("foo.star.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)

    response = make_request_to_host("foo.bar.star.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_star_does_not_match_root_domain
    response = make_request_to_host("star.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_star_does_not_match_wildcards_without_dot_boundary
    response = make_request_to_host("foostar.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_escapes_other_possible_regex_chars_in_wildcard_subdomains
    response = make_request_to_host("foo.star-dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-star-dot", response)

    response = make_request_to_host("foo.star-dotx#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)

    response = make_request_to_host("foo.dot.#{unique_test_class_id}", "/info/")
    assert_backend_match("wildcard-dot", response)

    response = make_request_to_host("foo.dotx#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end
end
