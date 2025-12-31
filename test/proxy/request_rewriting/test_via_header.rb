require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestViaHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  # We don't want to add Via headers by default, since it may mess with
  # backend server gzipping and prevent circular requests.
  #
  # See templates/etc/trafficserver/records.config.etlua's
  # proxy.config.http.insert_request_via_str comments.
  def test_does_not_add_via_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute(data["headers"]["via"])
  end

  def test_passes_along_existing_via_header
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
      :headers => { "Via" => "foo" },
    }))
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("foo", data["headers"]["via"])
  end
end
