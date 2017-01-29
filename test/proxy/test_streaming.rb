require_relative "../test_helper"

class Test::Proxy::TestStreaming < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_streaming_responses
    request = Typhoeus::Request.new("http://127.0.0.1:9080/api/chunked?#{unique_test_id}", http_options)
    chunks = []
    chunk_timers = []
    request.on_body do |chunk|
      chunks << chunk
      chunk_timers << Time.now.utc
    end
    response = request.run

    assert_response_code(200, response)
    assert_equal("chunked", response.headers["Transfer-Encoding"])
    assert_equal(["hello", "salutations", "goodbye"], chunks)
    assert_operator((chunk_timers[1] - chunk_timers[0]), :>, 0.4)
    assert_operator((chunk_timers[2] - chunk_timers[1]), :>, 0.4)
  end

  # TODO: nginx didn't use to support chunked request streaming:
  # http://forum.nginx.org/read.php?2,243073,243074#msg-243074 However, I
  # believe this has changed with the introduction of the
  # `proxy_request_buffering` option. So we should see about revisiting this,
  # since streaming requests would be ideal.
  def test_streaming_requests
    skip("Request streaming is not currently supported. Revisit with proxy_request_buffering setting.")

    # For reference, here was the inactive test from the old Node.js test
    # suite, where I think we at least got the logic for performing this test
    # down (even though we were never streaming):
    #
    # var req = http.request({
    #   host: 'localhost',
    #   port: 9080,
    #   //port: 9444,
    #   path: '/receive_chunks?api_key=' + this.apiKey,
    #   method: 'POST',
    #   headers: {
    #     'Transfer-Encoding': 'chunked',
    #   },
    # }, function(response) {
    #   var body = '';
    #   response.on('data', function(chunk) {
    #     body += chunk.toString();
    #   });
    #
    #   response.on('end', function() {
    #     var data = JSON.parse(body);
    #     data.chunks.should.eql([
    #       'hello',
    #       'greetings',
    #       'goodbye',
    #     ]);
    #
    #     data.chunkTimeGaps.length.should.eql(2);
    #     data.chunkTimeGaps[0].should.be.greaterThan(400);
    #     data.chunkTimeGaps[1].should.be.greaterThan(400);
    #
    #     data.request_encoding.should.eql('chunked');
    #
    #     done();
    #   });
    # });
    #
    # req.setNoDelay(true);
    #
    # req.write('hello');
    # setTimeout(function() {
    #   req.write('greetings');
    #   setTimeout(function() {
    #     req.write('goodbye');
    #     req.end();
    #   }, 500);
    # }, 500);

    # For reference, here's some initial experiments with streaming request
    # chunks using Ethon (it's not directly supported in Typhoeus):
    #
    # easy = Ethon::Easy.new
    # easy.http_request("www.httpbin.org/put", :put)
    # easy.headers = { "Transfer-Encoding" => "chunked" }
    # easy.readfunction do |stream, size, num, object|
    #   puts "STREAM: #{stream.inspect}"
    #   puts "SIZE: #{size.inspect}"
    #   puts "NUM: #{num.inspect}"
    #   puts "OBJECT: #{object.inspect}"
    #   chunk = "foo"
    #   size = chunk.bytesize
    #   sleep 2
    #   stream.write_string(chunk, size)
    #   size
    # end
    # easy.infilesize = 3
    # easy.perform
    #
    # puts easy.response_code.inspect
    # puts easy.response_body.inspect
  end
end
