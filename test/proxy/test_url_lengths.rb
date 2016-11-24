require_relative "../test_helper"

class TestProxyUrlLengths < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_url_length_limit
    response = make_request_with_url_length(8192)

    assert_equal(200, response.code, response.body)
    data = MultiJson.load(response.body)
    assert_includes(response.request.base_url, data["url"]["path"])
    assert_operator(data["url"]["path"].length, :>, 8000)
  end

  def test_url_length_limit_exceeded
    response = make_request_with_url_length(8193)

    assert_equal(414, response.code, response.body)
  end

  private

  def make_request_with_url_length(length)
    other_line_content = "GET  HTTP/1.1\r\n"
    path = "/api/info/?"
    path += "a" * (length - path.length - other_line_content.length)
    Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
  end
end
