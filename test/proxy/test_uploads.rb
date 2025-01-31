require_relative "../test_helper"

class Test::Proxy::TestUploads < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  # parallelize_me!

  def setup
    super
    setup_server
  end

  def test_no_multipart_post_request_body_size_limit
    file_size = 20 * 1024 * 1024 # 20MB
    with_file_of_size(file_size) do |file|
      response = Typhoeus.post("http://127.0.0.1:9080/api/upload", http_options.deep_merge({
        :body => { :upload => file },
      }))

      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data["upload_size"])
    end
  end

  def test_no_post_request_body_size_limit
    file_size = 20 * 1024 * 1024 # 20MB
    with_file_of_size(file_size) do |file|
      response = Typhoeus.post("http://127.0.0.1:9080/api/info/?post", http_options.deep_merge({
        :body => file.read,
      }))

      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data.fetch("headers").fetch("content-length").to_i)
    end
  end

  def test_no_put_request_body_size_limit
    file_size = 20 * 1024 * 1024 # 20MB
    with_file_of_size(file_size) do |file|
      # 100.times do
      1.times do
      file.rewind
      response = Typhoeus.put("http://127.0.0.1:9080/api/info/?put", http_options.deep_merge({
        :body => file.read,
      }))

      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data.fetch("headers").fetch("content-length").to_i)
      end
    end
  end

  def test_no_patch_request_body_size_limit
    file_size = 20 * 1024 * 1024 # 20MB
    with_file_of_size(file_size) do |file|
      # 100.times do
      1.times do
      file.rewind
      response = Typhoeus.patch("http://127.0.0.1:9080/api/info/?patch", http_options.deep_merge({
        :body => file.read,
      }))

      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data.fetch("headers").fetch("content-length").to_i)
      end
    end
  end

  def test_no_get_request_body_size_limit
    file_size = 20 * 1024 * 1024 # 20MB
    with_file_of_size(file_size) do |file|
      # 100.times do
      1.times do
      file.rewind
      response = Typhoeus.get("http://127.0.0.1:9080/api/info/?get", http_options.deep_merge({
        :body => file.read,
      }))

      assert_response_code(200, response)
      data = MultiJson.load(response.body)
      assert_equal(file_size, data.fetch("headers").fetch("content-length").to_i)
      end
    end
  end

  private

  def with_file_of_size(file_size)
    file_size = 20 * 1024 * 1024 # 20MB
    file = Tempfile.new("large")
    chunk_size = 1024 * 1024
    chunks = file_size / chunk_size
    chunks.times { file.write(SecureRandom.random_bytes(chunk_size)) }
    file.flush
    file.rewind

    yield file
  ensure
    file.close
    file.unlink
  end
end
