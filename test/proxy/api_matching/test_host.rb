require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestHost < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "foo.#{unique_test_class_id}",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host" },
            ],
          },
        },
      ])
    end
  end

  def test_matches_host
    response = make_request_to_host("foo.#{unique_test_class_id}", "/info/")
    assert_backend_match("host", response)
  end

  def test_matches_host_case_insensitively
    response = make_request_to_host("FOO.#{unique_test_class_id}", "/info/")
    assert_backend_match("host", response)
  end

  def test_does_not_match_unknown_host
    response = make_request_to_host("bar-foo.#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end
end
