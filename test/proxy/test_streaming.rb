require_relative "../test_helper"

class TestProxyStreaming < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_streaming_responses
    request = Typhoeus::Request.new("http://127.0.0.1:9080/chunked", @@http_options)
    chunks = []
    chunk_timers = []
    request.on_body do |chunk|
      chunks << chunk
      chunk_timers << Time.now.utc
    end
    response = request.run

    assert_equal(200, response.code, response.body)
    assert_equal("chunked", response.headers["Transfer-Encoding"])
    assert_equal(["hello", "salutations", "goodbye"], chunks)
    assert_operator((chunk_timers[1] - chunk_timers[0]), :>, 0.4)
    assert_operator((chunk_timers[2] - chunk_timers[1]), :>, 0.4)
  end
end
