require_relative "../../test_helper"

class Test::Proxy::KeepAlive::TestClientSide < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_reuses_connections
    @debug_output = ""

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", debug_http_options)
    assert_equal(200, response.code, response.body)

    response = Typhoeus.get("http://127.0.0.1:9080/api/hello", debug_http_options)
    assert_equal(200, response.code, response.body)

    # Ensure that curl's debug output contains the indicator of re-using a
    # keepalive connection.
    assert_match("Re-using existing connection", @debug_output)
  end

  def test_timeout_is_configurable
    override_config({
      :nginx => {
        # Test 0 seconds to disable keepalive.
        :keepalive_timeout => 0,
      },
    }, "--router") do
      @debug_output = ""

      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", debug_http_options)
      assert_equal(200, response.code, response.body)

      response = Typhoeus.get("http://127.0.0.1:9080/api/hello", debug_http_options)
      assert_equal(200, response.code, response.body)

      # Since keepalive is disabled, ensure that curl's debug output does not
      # contain the indicator of re-using a keepalive connection.
      refute_match("Re-using existing connection", @debug_output)
    end
  end

  private

  def debug_http_options
    http_options.deep_merge({
      # Provide a custom debug callback that doesn't print to STDOUT to curl's
      # debug output (https://github.com/typhoeus/typhoeus/issues/247).
      :verbose => true,
      :debugfunction => proc do |handle, type, data, size, udata|
        if(type == :text)
          @debug_output << data.read_string(size)
        end
        0
      end,
    })
  end
end
