require_relative "../../test_helper"

class Test::Proxy::ResponseRewriting::TestContentTypeHeader < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  # This is a side-effect of setting the X-Cache header in OpenResty. It
  # appears like OpenResty forces a default text/plain content-type when it
  # changes any other header if the content-type isn't already set. If this
  # changes in the future to retaining no header, that should be fine, just
  # testing current behavior.
  def test_changes_empty_content_type_to_text_plain
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?content_type=", http_options)
    assert_response_code(200, response)
    assert_equal("text/plain", response.headers["content-type"])
  end

  def test_does_not_change_existing_content_type
    response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000?content_type=Qwerty", http_options)
    assert_response_code(200, response)
    assert_equal("Qwerty", response.headers["content-type"])
  end
end
