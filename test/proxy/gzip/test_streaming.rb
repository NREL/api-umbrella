require_relative "../../test_helper"

class Test::Proxy::Gzip::TestStreaming < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_streams_small_response_as_gzipped_chunks
    request = Typhoeus::Request.new("http://127.0.0.1:9080/api/compressible-delayed-chunked/5?#{unique_test_id}", http_options.deep_merge(:accept_encoding => "gzip"))
    chunks = []
    chunk_time_gaps = []
    last_chunk_at = nil
    request.on_body do |chunk|
      chunks << chunk

      current_chunk_at = Time.now.utc
      if(last_chunk_at)
        chunk_time_gaps << (current_chunk_at.to_f - last_chunk_at.to_f)
      end
      last_chunk_at = current_chunk_at
    end
    response = request.run

    assert_response_code(200, response)
    assert_equal("gzip", response.headers["content-encoding"])
    assert_equal("chunked", response.headers["transfer-encoding"])
    assert_equal(15, chunks.join("").bytesize)

    # Ensure we have at least 3 chunks (it may be 4, due to gzipping messing
    # with things).
    assert_operator(chunks.length, :>=, 3)

    # Make sure that there were 2 primary gaps between chunks from the server
    # (again, gzipping may introduce other chunks, but we're just interested in
    # ensuring the chunks sent back from the server are present).
    long_time_gaps = chunk_time_gaps.select { |gap| gap >= 0.4 }
    assert_equal(2, long_time_gaps.length)
  end

  def test_client_no_gzip_streams_small_uncompressed_chunks
    request = Typhoeus::Request.new("http://127.0.0.1:9080/api/compressible-delayed-chunked/10?#{unique_test_id}", http_options)
    chunks = []
    request.on_body do |chunk|
      chunks << chunk
    end
    response = request.run

    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    assert_equal("chunked", response.headers["transfer-encoding"])
    assert_equal(30, chunks.join("").bytesize)

    assert_equal(3, chunks.length)
  end

  def test_client_no_gzip_streams_large_uncompressed_chunks
    request = Typhoeus::Request.new("http://127.0.0.1:9080/api/compressible-delayed-chunked/50000?#{unique_test_id}", http_options)
    chunks = []
    chunk_time_gaps = []
    last_chunk_at = nil
    request.on_body do |chunk|
      chunks << chunk

      current_chunk_at = Time.now.utc
      if(last_chunk_at)
        chunk_time_gaps << (current_chunk_at.to_f - last_chunk_at.to_f)
      end
      last_chunk_at = current_chunk_at
    end
    response = request.run

    assert_response_code(200, response)
    refute(response.headers["content-encoding"])
    assert_equal("chunked", response.headers["transfer-encoding"])
    assert_equal(150000, chunks.join("").bytesize)

    # With response sizes this big, we'll have a lot of response chunks, but
    # what we mainly want to test is that there are distinct gaps in the chunks
    # corresponding to how the backend streams stuff back.
    long_time_gaps = chunk_time_gaps.select { |gap| gap >= 0.4 }
    short_time_gaps = chunk_time_gaps.select { |gap| gap < 0.4 }
    assert_equal(2, long_time_gaps.length)
    assert_operator(short_time_gaps.length, :>=, 10)
  end
end
