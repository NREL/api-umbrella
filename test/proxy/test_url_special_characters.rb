require_relative "../test_helper"

class Test::Proxy::TestUrlSpecialCharacters < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_utf8_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/utf8/✓/encoded_utf8/%E2%9C%93/?utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xC2\xAC\xC2\xB6\xC2\xAA\xC3\xBE\xC2\xA4l&more_utf8_hex_lowercase=\xc2\xac\xc2\xb6\xc2\xaa\xc3\xbe\xc2\xa4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("✓", data["url"]["query"]["utf8"])
    assert_equal("✓", data["url"]["query"]["utf8_url_encoded"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8_hex"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8_hex_lowercase"])
    assert_includes(data["raw_url"], "/info/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/?utf8=✓&utf8_url_encoded=%E2%9C%93&more_utf8=¬¶ªþ¤l&more_utf8_hex=\xC2\xAC\xC2\xB6\xC2\xAA\xC3\xBE\xC2\xA4l&more_utf8_hex_lowercase=\xc2\xac\xc2\xb6\xc2\xaa\xc3\xbe\xc2\xa4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l")
  end

  def test_slashes_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash/?forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/slash", data["url"]["query"]["forward_slash"])
    assert_equal("/", data["url"]["query"]["encoded_forward_slash"])
    assert_equal("\\", data["url"]["query"]["encoded_back_slash"])
    assert_includes(data["raw_url"], "/info/extra/slash/some\\backslash/encoded\\backslash/encoded/slash/?forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C")
  end
end
