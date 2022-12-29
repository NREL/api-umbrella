require_relative "../../test_helper"

# Previously, API Umbrella matched the API "frontend_host" on both the hostname
# and the port in the "Host" header. However, to better align with nginx, we
# now only match on the hostname portion of the Host header (ignoring the
# port). So these are various sanity checks to ensure we no longer match based
# on port, and instead take the first matching hostname.
class Test::Proxy::ApiMatching::TestHostPort < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "#{unique_test_class_id}:7777",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-with-non-matching-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}:80",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-with-default-http-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}:443",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-with-default-https-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}:9080",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-with-matching-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}:9080",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-with-matching-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}-other",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "other-host-with-no-port" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}-other:9080",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "other-host-with-port" },
            ],
          },
        },
      ])
    end
  end

  def test_matches_first_api_with_host_and_matching_port
    response = make_request_to_host("#{unique_test_class_id}:7777", "/info/")
    assert_backend_match("host-with-non-matching-port", response)
  end

  def test_matches_first_api_with_host_ignoring_matching_port
    response = make_request_to_host("#{unique_test_class_id}:9080", "/info/")
    assert_backend_match("host-with-non-matching-port", response)
  end

  def test_matches_first_api_with_host_ignoring_default_port
    response = make_request_to_host("#{unique_test_class_id}:80", "/info/")
    assert_backend_match("host-with-non-matching-port", response)
  end

  def test_matches_first_api_with_host_ignoring_no_port
    response = make_request_to_host(unique_test_class_id, "/info/")
    assert_backend_match("host-with-non-matching-port", response)
  end

  def test_matches_first_api_with_host_ignoring_forwarded_proto
    response = make_request_to_host(unique_test_class_id, "/info/", :headers => { "X-Forwarded-Proto" => "https" })
    assert_backend_match("host-with-non-matching-port", response)
  end

  def test_matches_first_api_with_host_lacking_port
    response = make_request_to_host("#{unique_test_class_id}-other", "/info/")
    assert_backend_match("other-host-with-no-port", response)
  end

  def test_matches_first_api_with_host_lacking_port_ignoring_port
    response = make_request_to_host("#{unique_test_class_id}-other:123", "/info/")
    assert_backend_match("other-host-with-no-port", response)
  end
end
