require "test_helper"

class TestProxyUploads < Minitest::Test
  include ApiUmbrellaTests::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_large_uploads
    begin
      file_size = 20 * 1024 * 1024 # 20MB
      file = Tempfile.new("large")
      chunk_size = 1024 * 1024
      chunks = file_size / chunk_size
      chunks.times { file.write(SecureRandom.random_bytes(chunk_size)) }

      response = Typhoeus.post("http://127.0.0.1:9080/upload", @@http_options.deep_merge({
        :body => { :upload => file },
      }))

      assert_equal(200, response.code, response.body)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data["upload_size"])
    ensure
      file.close
      file.unlink
    end
  end
end
