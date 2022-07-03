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
    assert_equal("/info/utf8/✓/encoded_utf8/✓/", data["url"]["pathname"])
    assert_equal("✓", data["url"]["query"]["utf8"])
    assert_equal("✓", data["url"]["query"]["utf8_url_encoded"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8_hex"])
    assert_equal("¬¶ªþ¤l", data["url"]["query"]["more_utf8_hex_lowercase"])
    assert_equal("http://127.0.0.1/info/utf8/%E2%9C%93/encoded_utf8/%E2%9C%93/?utf8=%E2%9C%93&utf8_url_encoded=%E2%9C%93&more_utf8=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&more_utf8_hex_lowercase=%C2%AC%C2%B6%C2%AA%C3%BE%C2%A4l&actual_backslash_x=\\xAC\\xB6\\xAA\\xFE\\xA4l", data["raw_url"])
  end

  def test_slashes_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/extra//slash/some\\backslash/encoded%5Cbackslash/encoded%2Fslash/?forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/extra/slash/some\\backslash/encoded\\backslash/encoded/slash/", data["url"]["pathname"])
    assert_equal("/slash", data["url"]["query"]["forward_slash"])
    assert_equal("/", data["url"]["query"]["encoded_forward_slash"])
    assert_equal("\\", data["url"]["query"]["encoded_back_slash"])
    assert_equal("http://127.0.0.1/info/extra//slash/some%5Cbackslash/encoded%5Cbackslash/encoded/slash/?forward_slash=/slash&encoded_forward_slash=%2F&back_slash=\\&encoded_back_slash=%5C", data["raw_url"])
  end

  def test_unescaped_spaces_path_url
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/space/ /", http_options)
    assert_response_code(400, response)
  end

  def test_unescaped_spaces_query_url
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/space/?space= &foo", http_options)
    assert_response_code(400, response)
  end

  def test_escaped_spaces_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/encoded_space/%20/plus_space/+/?encoded_space=%20&plus_space=+", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/encoded_space/ /plus_space/+/", data["url"]["pathname"])
    assert_equal(" ", data["url"]["query"]["encoded_space"])
    assert_equal(" ", data["url"]["query"]["plus_space"])
    assert_equal("http://127.0.0.1/info/encoded_space/%20/plus_space/+/?encoded_space=%20&plus_space=+", data["raw_url"])
  end

  def test_ampersand_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/ampersand/&/encoded_ampersand/%26/?encoded_ampersand=%26", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/ampersand/&/encoded_ampersand/&/", data["url"]["pathname"])
    assert_equal("&", data["url"]["query"]["encoded_ampersand"])
    assert_equal("http://127.0.0.1/info/ampersand/&/encoded_ampersand/&/?encoded_ampersand=%26", data["raw_url"])
  end

  def test_question_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/encoded_question/%3F/?encoded_question=%3F", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/encoded_question/?/", data["url"]["pathname"])
    assert_equal("?", data["url"]["query"]["encoded_question"])
    assert_equal("http://127.0.0.1/info/encoded_question/%3F/?encoded_question=%3F", data["raw_url"])
  end

  def test_percent_urls
    response = Typhoeus.get("http://127.0.0.1:9080/api/info/encoded_percent/%25/?percent=%&encoded_percent=%25", http_options)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/encoded_percent/%/", data["url"]["pathname"])
    assert_equal("%", data["url"]["query"]["percent"])
    assert_equal("%", data["url"]["query"]["encoded_percent"])
    assert_equal("http://127.0.0.1/info/encoded_percent/%25/?percent=%&encoded_percent=%25", data["raw_url"])
  end
end
