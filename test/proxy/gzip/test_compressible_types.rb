require_relative "../../test_helper"

class Test::Proxy::Gzip::TestCompressibleTypes < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  [
    "application/atom+xml",
    "application/javascript",
    "application/json",
    "application/rss+xml",
    "application/x-javascript",
    "application/xml",
    "text/css",
    "text/csv",
    "text/html",
    "text/javascript",
    "text/plain",
    "text/xml",
  ].each do |mime|
    mime_method_name = mime.gsub(/[^\w]+/, "_")
    define_method("test_gzip_response_for_#{mime_method_name}") do
      response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000", http_options.deep_merge({
        :accept_encoding => "gzip",
        :params => { :content_type => mime },
      }))
      assert_response_code(200, response)
      assert_includes(response.headers.keys, "Content-Type")
      assert_equal(mime, response.headers["Content-Type"])
      assert_equal("gzip", response.headers["Content-Encoding"])
      assert_equal(1000, response.body.bytesize)
    end
  end

  [
    "",
    "image/png",
    "application/octet-stream",
    "application/x-perl",
    "application/x-whatever-unknown",
  ].each do |mime|
    mime_method_name = mime.gsub(/[^\w]+/, "_")
    define_method("test_non_gzip_response_for_#{mime_method_name}") do
      response = Typhoeus.get("http://127.0.0.1:9080/api/compressible/1000", http_options.deep_merge({
        :accept_encoding => "gzip",
        :params => { :content_type => mime },
      }))
      assert_response_code(200, response)
      if(mime == "")
        refute_includes(response.headers.keys, "Content-Type")
        assert_nil(response.headers["Content-Type"])
      else
        assert_includes(response.headers.keys, "Content-Type")
        assert_equal(mime, response.headers["Content-Type"])
      end
      refute(response.headers["Content-Encoding"])
      assert_equal(1000, response.body.bytesize)
    end
  end
end
