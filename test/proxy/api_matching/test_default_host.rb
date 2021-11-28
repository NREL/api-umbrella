require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestDefaultHost < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "default-#{unique_test_class_id}",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-default" },
            ],
          },
        },
        {
          :frontend_host => "other-#{unique_test_class_id}",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/", :backend_prefix => "/" }],
          :settings => {
            :headers => [
              { :key => "X-Test-Backend", :value => "host-other" },
            ],
          },
        },
      ])
    end
  end

  def test_no_default_host_by_default
    response = make_request_to_host("other-#{unique_test_class_id}", "/info/")
    assert_backend_match("host-other", response)

    response = make_request_to_host("default-#{unique_test_class_id}", "/info/")
    assert_backend_match("host-default", response)

    response = make_request_to_host("unknown-#{unique_test_class_id}", "/info/")
    assert_response_code(404, response)
  end

  def test_uses_default_host_as_fallback_if_set
    override_config({
      :hosts => [
        {
          :hostname => "default-#{unique_test_class_id}",
          :default => true,
        },
      ],
    }) do
      response = make_request_to_host("other-#{unique_test_class_id}", "/info/")
      assert_backend_match("host-other", response)

      response = make_request_to_host("default-#{unique_test_class_id}", "/info/")
      assert_backend_match("host-default", response)

      response = make_request_to_host("unknown-#{unique_test_class_id}", "/info/")
      assert_backend_match("host-default", response)
    end
  end
end
