require_relative "../test_helper"

class Test::Proxy::TestUploads < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_large_uploads
    file_size = 20 * 1024 * 1024 # 20MB
    file = Tempfile.new("large")
    chunk_size = 1024 * 1024
    chunks = file_size / chunk_size
    chunks.times { file.write(SecureRandom.random_bytes(chunk_size)) }

    response = Typhoeus.post("http://127.0.0.1:9080/api/upload", http_options.deep_merge({
      :body => { :upload => file },
    }))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(file_size, data["upload_size"])
  ensure
    file.close
    file.unlink
  end
end
