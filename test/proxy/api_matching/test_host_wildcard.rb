require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestHostWildcard < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching

  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "#{unique_test_class_id}-path",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/path/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "specific-host-path" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}-before",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "specific-host-before" },
            ],
          },
        },
        {
          :frontend_host => "*",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "wildcard" },
            ],
          },
        },
        {
          :frontend_host => "#{unique_test_class_id}-after",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "specific-host-after" },
            ],
          },
        },
      ])
    end
  end

  def test_uses_wildcard_for_unknown_host
    response = make_request_to_host("#{unique_test_id}.foo", "/#{unique_test_class_id}/info/")
    assert_backend_match("wildcard", response)
  end

  def test_matches_more_specific_hosts_defined_before_wildcard
    response = make_request_to_host("#{unique_test_class_id}-before", "/#{unique_test_class_id}/info/")
    assert_backend_match("specific-host-before", response)
  end

  def test_does_not_match_more_specific_hosts_defined_after_wildcard
    response = make_request_to_host("#{unique_test_class_id}-after", "/#{unique_test_class_id}/info/")
    assert_backend_match("wildcard", response)
  end

  def test_uses_wildcard_if_more_specific_host_exists_but_does_not_match_path
    response = make_request_to_host("#{unique_test_class_id}-path", "/#{unique_test_class_id}/path/info/")
    assert_backend_match("specific-host-path", response)

    response = make_request_to_host("#{unique_test_class_id}-path", "/#{unique_test_class_id}/info/")
    assert_backend_match("wildcard", response)
  end
end
