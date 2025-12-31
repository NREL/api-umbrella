require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestPathPrefixes < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching

  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "other-#{unique_test_class_id}",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/specific/", :backend_prefix => "/info/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "specific-prefix-other-host" },
            ],
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/specific/", :backend_prefix => "/info/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "specific-prefix" },
            ],
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-trailing", :backend_prefix => "/info/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "no-trailing-prefix" },
            ],
          },
        },
      ])
    end
  end

  def test_matches_path_prefix_host_combo
    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/specific/")
    assert_backend_match("specific-prefix", response)

    response = make_request_to_host("other-#{unique_test_class_id}", "/#{unique_test_class_id}/specific/")
    assert_backend_match("specific-prefix-other-host", response)

    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/")
    assert_response_code(404, response)

    response = make_request_to_host("other-#{unique_test_class_id}", "/#{unique_test_class_id}/")
    assert_response_code(404, response)
  end

  def test_matches_beyond_prefix
    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/specific/abc/xyz")
    assert_backend_match("specific-prefix", response)
  end

  def test_requires_trailing_slash_match
    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/specific")
    assert_response_code(404, response)

    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/no-trailing")
    assert_backend_match("no-trailing-prefix", response)

    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/no-trailing/")
    assert_backend_match("no-trailing-prefix", response)
  end

  def test_matches_case_sensitively
    response = make_request_to_host("127.0.0.1", "/#{unique_test_class_id}/SPECIFIC/")
    assert_response_code(404, response)
  end
end
