require_relative "../test_helper"

class Test::Proxy::TestHttpHeaderLengths < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_total_header_length_limit
    response = make_request_with_header_lengths(:size => 32000, :line_length => 4048)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["request_length"], :>=, 32000)
    assert_operator(data["request_length"], :<, 34000)
  end

  def test_total_header_length_limit_exceeded
    response = make_request_with_header_lengths(:size => 34000, :line_length => 4048)

    assert_response_code(400, response)
  end

  def test_header_line_length_limit
    response = make_request_with_header_lengths(:size => 12000, :line_length => 8192)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    refute_nil(data["headers"]["x-test001"])
    assert_equal("x-test001: #{data["headers"]["x-test001"]}\r\n".length, 8192)
  end

  def test_header_line_length_limit_exceeded
    response = make_request_with_header_lengths(:size => 12000, :line_length => 8193)

    assert_response_code(400, response)
  end

  def test_no_limit_on_number_of_headers
    response = make_request_with_header_lengths(:size => 12000, :line_length => 24, :num_headers => 150)

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_operator(data["headers"].length, :>=, 150)
  end

  private

  def make_request_with_header_lengths(options = {})
    headers = http_options[:headers].merge({
      "Host" => "127.0.0.1:9080",
      "Connection" => "close",
      "User-Agent" => "Test",
      "Accept" => "*/*",
    })

    # Determine the length of the raw HTTP request with the default headers in
    # place.
    raw_request_length = "GET /info/ HTTP/1.1\r\n".freeze.length
    header_line_extra_raw_length = ": \r\n".freeze.length
    headers.each do |key, value|
      raw_request_length += key.length + value.length + header_line_extra_raw_length
    end

    # Add additional HTTP headers until we hit the various length limits.
    index = 1
    while(raw_request_length < options[:size])
      # If a maximum number of headers is passed in, abort once we hit that
      # limit.
      if(options[:num_headers] && headers.length >= options[:num_headers])
        break
      end

      # Add a new HTTP header with the maximum line length.
      key = "X-Test#{index.to_s.rjust(3, "0")}"
      value = "a" * (options[:line_length] - key.length - header_line_extra_raw_length)
      headers[key] = value

      # Keep track of the overall raw request length.
      raw_request_length += key.length + value.length + header_line_extra_raw_length

      # If the header we just added makes the overall request length exceed our
      # total limit, then truncate the last HTTP header so it fits.
      over_size_limit_by = raw_request_length - options[:size]
      if(over_size_limit_by > 0)
        headers[key] = value[0, value.length - over_size_limit_by]
      end

      index += 1
    end

    Typhoeus.get("http://127.0.0.1:9080/api/info/", http_options.merge({
      :headers => headers,
    }))
  end
end
