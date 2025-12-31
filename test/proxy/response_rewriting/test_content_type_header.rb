require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestContentTypeHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  # Ensure empty content types remain empty during proxying.
  # https://github.com/openresty/lua-nginx-module/pull/1445
  def test_keeps_empty_content_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?content_type=", http_options)
    assert_response_code(200, response)
    refute_includes(response.headers.keys, "Content-Type")
    assert_nil(response.headers["Content-Type"])
  end

  def test_does_not_change_existing_content_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?content_type=Qwerty", http_options)
    assert_response_code(200, response)
    assert_equal("Qwerty", response.headers["content-type"])
  end
end
