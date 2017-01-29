require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestUrlEncoding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  # Older test from when our proxy was Node.js. But still keep it for sanity
  # checking. Test for backslashes flipping to forward slashes:
  # https://github.com/joyent/node/pull/8459
  def test_passes_backslashes_to_backend
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/test\\backslash?test=\\hello", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("http://127.0.0.1/info/test\\backslash?test=\\hello", data["raw_url"])
  end
end
