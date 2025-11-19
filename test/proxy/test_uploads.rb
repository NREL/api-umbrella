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

  def test_mixed_uploads_stress_test
    requests = []

    info_get_requests = Array.new(200) do
      Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
        headers: {
          "X-Unique" => SecureRandom.hex(40),
        },
      }))
    end
    requests += info_get_requests

    read_body_requests = {}
    unread_body_requests = {}
    multipart_body_requests = {}
    above_max_body_size_requests = {}

    [:post, :put, :patch].each do |method|
      read_body_requests[method] = Array.new(5) do
        body = SecureRandom.random_bytes(5 * 1024 * 1024 + rand(-200..200)).freeze # 5MB
        Typhoeus::Request.new("http://127.0.0.1:9080/api/read-body", http_options.deep_merge({
          method: method,
          body: body,
          headers: {
            "Content-Type" => "text/plain",
            "X-Expected-Body-Size" => body.bytesize,
            "X-Expected-Body-Checksum" => Digest::SHA256.hexdigest(body),
          },
        }))
      end
      requests += read_body_requests[method]

      unread_body_requests[method] = Array.new(5) do
        body = SecureRandom.random_bytes(5 * 1024 * 1024 + rand(-200..200)).freeze # 5MB
        Typhoeus::Request.new("http://127.0.0.1:9080/api/unread-body", http_options.deep_merge({
          method: method,
          body: body,
          headers: {
            "Content-Type" => "text/plain",
            "X-Expected-Body-Size" => body.bytesize,
          },
        }))
      end
      requests += unread_body_requests[method]

      multipart_body_requests[method] = Array.new(5) do
        file = Tempfile.new("large")
        body = SecureRandom.random_bytes(5 * 1024 * 1024 + rand(-200..200)).freeze # 5MB
        file.write(body)
        Typhoeus::Request.new("http://127.0.0.1:9080/api/upload", http_options.deep_merge({
          # Workaround for PUT not working with Typhoeus and multipart uploads
          # currently:
          # https://github.com/typhoeus/typhoeus/issues/389#issuecomment-3186406150
          method: :post,
          customrequest: method.to_s.upcase,
          body: { upload: file },
          headers: {
            "X-Expected-Body-Size" => body.bytesize,
            "X-Expected-Body-Checksum" => Digest::SHA256.hexdigest(body),
          },
        }))
      end
      requests += multipart_body_requests[method]

      above_max_body_size_requests[method] = Array.new(5) do
        body = SecureRandom.random_bytes(5 * 1024 * 1024 + rand(-200..200)).freeze # 5MB
        Typhoeus::Request.new("https://127.0.0.1:9081/api-umbrella/v1/users", http_options.deep_merge({
          method: method,
          body: body,
          headers: {
            "Content-Type" => "text/plain",
          },
        }))
      end
      requests += above_max_body_size_requests[method]
    end

    hydra = Typhoeus::Hydra.new(max_concurrency: 10)
    requests.shuffle
    requests.each do |request|
      hydra.queue(request)
    end
    hydra.run

    requests.each do |request|
      puts request.response.code
    end

    assert_equal(200, info_get_requests.length)
    info_get_requests.each do |request|
      assert_response_code(200, request.response)
      request_headers = request.original_options.fetch(:headers)
      data = MultiJson.load(request.response.body)
      assert_equal(request_headers.fetch("X-Unique"), data.fetch("headers").fetch("x-unique"))
    end

    assert_equal(3, read_body_requests.length)
    read_body_requests.each do |method, method_requests|
      assert_equal(5, method_requests.length)
      method_requests.each do |request|
        assert_response_code(200, request.response)
        request_headers = request.original_options.fetch(:headers)
        data = MultiJson.load(request.response.body)
        assert_equal(request.original_options.fetch(:method).to_s.upcase, data.fetch("method"))
        assert_equal("text/plain", data.fetch("headers").fetch("content-type"))
        assert_equal(request_headers.fetch("X-Expected-Body-Size").to_s, data.fetch("headers").fetch("content-length"))
        assert_equal(request_headers.fetch("X-Expected-Body-Size"), data.fetch("body_size"))
        assert_equal(request_headers.fetch("X-Expected-Body-Checksum"), data.fetch("body_checksum"))
      end
    end

    assert_equal(3, unread_body_requests.length)
    unread_body_requests.each do |method, method_requests|
      assert_equal(5, method_requests.length)
      method_requests.each do |request|
        assert_response_code(200, request.response)
        request_headers = request.original_options.fetch(:headers)
        data = MultiJson.load(request.response.body)
        assert_equal(request.original_options.fetch(:method).to_s.upcase, data.fetch("method"))
        assert_equal(request_headers.fetch("X-Expected-Body-Size").to_s, data.fetch("http_content_length"))
        refute(data.key?("body_size"))
        refute(data.key?("body_checksum"))
      end
    end

    assert_equal(3, multipart_body_requests.length)
    multipart_body_requests.each do |method, method_requests|
      assert_equal(5, method_requests.length)
      method_requests.each do |request|
        assert_response_code(200, request.response)
        request_headers = request.original_options.fetch(:headers)
        data = MultiJson.load(request.response.body)
        assert_equal(request.original_options.fetch(:customrequest).to_s.upcase, data.fetch("method"))
        assert_match("multipart/form-data; boundary=", data.fetch("headers").fetch("content-type"))
        assert_in_delta(request_headers.fetch("X-Expected-Body-Size"), data.fetch("headers").fetch("content-length").to_i, 400)
        assert_equal(request_headers.fetch("X-Expected-Body-Size"), data.fetch("upload_size"))
        assert_equal(request_headers.fetch("X-Expected-Body-Checksum"), data.fetch("upload_checksum"))
      end
    end

    assert_equal(3, above_max_body_size_requests.length)
    above_max_body_size_requests.each do |method, method_requests|
      assert_equal(5, method_requests.length)
      method_requests.each do |request|
        assert_response_code((request.response.code == 502) ? 502 : 413, request.response)
        assert_equal("text/html", request.response.headers["content-type"])
      end
    end
  end
end
