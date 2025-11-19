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
    info_request_count = 200
    per_group_request_count = 5

    # When gathering debug details from curl, use our custom `debug_callback`
    # that adds this variable to exclude the body data, since we don't need to
    # retain that in the debug and it inflates memory use of this test to keep
    # it.
    Ethon::Easy::Callbacks.class_variable_set(:@@debug_callback_exclude_types, [:data_in, :data_out])

    # Make a bunch of basic, GET requests in parallel to the actual upload
    # tests to ensure non-upload requests remain unaffected by any upload
    # errors.
    info_get_requests = Array.new(info_request_count) do
      Typhoeus::Request.new("http://127.0.0.1:9080/api/info/", http_options.deep_merge({
        headers: {
          "X-Unique" => SecureRandom.hex(40),
        },
      }))
    end
    requests += info_get_requests

    # Make a bunch of requests that include a sizeable request body (5MB), but
    # try lots of combinations of approaches to test edge-case scenarios with
    # our various proxies.
    #
    # The first combination is to try requests that will be fully read by the
    # backend versus ones where the backend may close the connection while the
    # client is still sending data (and exceeding the nginx
    # `client_max_body_size` is just a common variation on this unread/early
    # close behavior).
    body_requests = {}
    [:read, :unread, :unread_above_max_body_size].each do |read_status|
      # Check to see how the proxies handle different response codes, ranging
      # from OK responses, to errors. When exceeding the
      # `client_max_body_size`, we only expect the nginx error, though.
      response_statuses = [200, 422, 500]
      if read_status == :unread_above_max_body_size
        response_statuses = [413]
      end
      response_statuses.each do |response_status|
        # Check how a multipart form upload is handled versus just a plain
        # request body, since that may also affect handling.
        [:plain, :multipart].each do |content_type|
          # Check how `Expect: 100-continue` versus no `Expect` header is
          # handled, since that changes the flow slightly if the 100 Continue
          # response is returned.
          [:expect_none, :expect_continue].each do |expect_status|
            # Check different HTTP methods, since we've sometimes seen
            # different POST vs PUT behavior.
            [:post, :put, :patch].each do |http_method|
              key = {
                read_status: read_status,
                response_status: response_status,
                content_type: content_type,
                expect_status: expect_status,
                http_method: http_method,
              }

              body_requests[key] = Array.new(per_group_request_count) do
                # Randomize the exact body size a bit as an extra sanity check.
                body = SecureRandom.random_bytes(5 * 1024 * 1024 + rand(-200..200)).freeze # 5MB

                # Begin constructing the request using the HTTP method and
                # include some headers that we can use to sanity check the
                # results.
                options = {
                  method: http_method,
                  verbose: true,
                  headers: {
                    "X-Expected-Status" => response_status,
                    "X-Expected-Body-Size" => body.bytesize,
                    "X-Expected-Body-Checksum" => Digest::SHA256.hexdigest(body),
                  },
                }

                # Hit different backend endpoints depending on which situation
                # we're trying to test.
                url = case read_status
                when :read
                  case content_type
                  when :plain
                    "http://127.0.0.1:9080/api/read-body"
                  when :multipart
                    "http://127.0.0.1:9080/api/upload"
                  end
                when :unread
                  "http://127.0.0.1:9080/api/unread-body-#{response_status}"
                when :unread_above_max_body_size
                  "http://127.0.0.1:9080/api/max-body-size"
                end

                # Upload the data either by assigning the direct body, or by
                # making curl do a multipart upload.
                case content_type
                when :plain
                  options[:body] = body
                  options[:headers]["Content-Type"] = "text/plain"
                when :multipart
                  file = Tempfile.new("uploads_stress_test")
                  file.write(body)
                  options[:body] = { upload: file }

                  # Workaround for PUT not working with Typhoeus and multipart uploads
                  # currently:
                  # https://github.com/typhoeus/typhoeus/issues/389#issuecomment-3186406150
                  options[:method] = :post
                  options[:customrequest] = http_method.to_s.upcase
                else
                  raise "Unknown content type"
                end

                # Change whether the `Expect: 100-continue` header will be sent
                # in or not.
                case expect_status
                when :expect_none
                  options[:headers]["Expect"] = ""
                when :expect_continue
                  options[:headers]["Expect"] = "100-continue"
                else
                  raise "Unknown expect status"
                end

                Typhoeus::Request.new(url, http_options.deep_merge(options))
              end

              requests += body_requests[key]
            end
          end
        end
      end
    end

    # Make all of these requests in random order and with some parallelization
    # to see how that affects things.
    hydra = Typhoeus::Hydra.new(max_concurrency: 10)
    requests.shuffle
    requests.each do |request|
      hydra.queue(request)
    end
    hydra.run

    # Validate that all of the basic GET requests happening in parallel worked
    # successfully.
    assert_equal(info_request_count, info_get_requests.length)
    info_get_requests.each do |request|
      assert_response_code(200, request.response)
      request_headers = request.original_options.fetch(:headers)
      data = MultiJson.load(request.response.body)
      assert_equal(request_headers.fetch("X-Unique"), data.fetch("headers").fetch("x-unique"))
    end

    # Validate all of our upload requests based on what's expected for each
    # situation.
    assert_operator(body_requests.length, :>, 50)
    total_warnings = 0
    body_requests.each do |group, group_requests|
      assert_equal(per_group_request_count, group_requests.length)
      group_warnings = []
      group_requests.each do |request|
        request_headers = request.original_options.fetch(:headers)
        response = request.response

        # Since we're looping over lots of requests, test failures may be hard
        # to understand, so construct an extra debug message that can be
        # included with any failures.
        error_message = "Request in group failed\n\nGroup: #{group.inspect}\n\n#{response_error_message(response)}"
        assert(response, error_message)

        # Traffic Server seems to sporadically return 502 Bad Gateway errors
        # when the backend closes the connection while it's still being
        # uploaded. While not ideal (since the user may not be able to receive
        # the original response from the underlying backend), this is probably
        # something of an edge-case. Since we've been seemingly living with
        # this for a long time, we'll log these as warnings, but not fail in
        # these cases.
        #
        # Issue about this:
        # https://github.com/apache/trafficserver/issues/10393 While it happens
        # more readily in Traffic Server 9.2+, this parallelized test suite
        # seems to reveal it also occurred in 9.1, maybe just less frequently.
        if response.code == 502 && (group.fetch(:read_status) == :unread || group.fetch(:read_status) == :unread_above_max_body_size)
          group_warnings << "Improper (but acceptable) response code: #{response.code}"
          assert_response_code(502, response, error_message)
        else
          assert_response_code(group.fetch(:response_status), response, error_message)
        end

        # Parse any JSON responses that include data.
        data = if response.headers["content-type"] == "application/json"
          MultiJson.load(response.body)
        else
          {}
        end

        # For successfully read responses, verify the `Content-Type` header
        # received by the underlying API.
        if group.fetch(:read_status) == :read
          case group.fetch(:content_type)
          when :plain
            assert_equal("text/plain", data.fetch("headers").fetch("content-type"), error_message)
          when :multipart
            assert_match("multipart/form-data; boundary=", data.fetch("headers").fetch("content-type"), error_message)
          else
            raise "Unknown content type"
          end
        end

        # Validate that `Expect: 100-continue` requests are sent and handled as
        # expected with the intermediate `100 Continue` response, regardless of
        # other settings.
        case group.fetch(:expect_status)
        when :expect_none
          refute_match(/Expect:/i, response.debug_info.header_out.join(""), error_message)
          refute_match("HTTP/1.1 100 Continue", response.debug_info.header_in.join(""), error_message)
        when :expect_continue
          assert_match("Expect: 100-continue", response.debug_info.header_out.join(""), error_message)
          assert_match("HTTP/1.1 100 Continue", response.debug_info.header_in.join(""), error_message)
        else
          raise "Unknown expect status"
        end

        case response.code
        when 413
          # For the 413 Payload Too Large responses, validate that they are the
          # expected ones coming from nginx.
          assert_equal("text/html", response.headers["content-type"], error_message)
          assert_match("413 Request Entity Too Large", response.body, error_message)
          assert_match("<center>openresty</center>", response.body, error_message)
          assert_match(%r{http/1\.1 api-umbrella \(ApacheTrafficServer \[c[ M]s f \]\)}, response.headers["via"], error_message)
        when 502
          # For the 502 Bad Gateway errors (which aren't ideal for cancelled
          # requests, but we're validating the current Traffic Server
          # behavior), validate that they are coming from Traffic Server, since
          # that's the layer with this behavior.
          assert_equal("text/html", response.headers["content-type"], error_message)
          assert_match("Server Connection Closed", response.body, error_message)
          assert_match("Description: The server requested closed the connection before", response.body, error_message)
          assert_match(%r{http/1\.1 api-umbrella \(ApacheTrafficServer \[c[ M]sEf \]\)}, response.headers["via"], error_message)
        else
          # For other successful responses, validate the HTTP method recieved
          # matches the expectations of the request.
          expected_method = (request.original_options[:customrequest] || request.original_options.fetch(:method)).to_s.upcase
          assert_equal(expected_method, data.fetch("method"))

          # Validate the response data to verify that the underlying API
          # received the expected body data in its entirety. The exact output
          # structure depends a bit on which API was being hit.
          case group.fetch(:read_status)
          when :read
            case group.fetch(:content_type)
            when :multipart
              assert_in_delta(request_headers.fetch("X-Expected-Body-Size"), data.fetch("headers").fetch("content-length").to_i, 400, error_message)
              assert_equal(request_headers.fetch("X-Expected-Body-Size"), data.fetch("upload_size"), error_message)
              assert_equal(request_headers.fetch("X-Expected-Body-Checksum"), data.fetch("upload_checksum"), error_message)
            when :plain
              assert_equal(request_headers.fetch("X-Expected-Body-Size").to_s, data.fetch("headers").fetch("content-length"), error_message)
              assert_equal(request_headers.fetch("X-Expected-Body-Size"), data.fetch("body_size"), error_message)
              assert_equal(request_headers.fetch("X-Expected-Body-Checksum"), data.fetch("body_checksum"), error_message)
            else
              raise "Unknown content type"
            end
          when :unread
            case group.fetch(:content_type)
            when :multipart
              assert_in_delta(request_headers.fetch("X-Expected-Body-Size"), data.fetch("http_content_length").to_i, 400, error_message)
            when :plain
              assert_equal(request_headers.fetch("X-Expected-Body-Size"), data.fetch("http_content_length").to_i, error_message)
            else
              raise "Unknown content type"
            end
          else
            raise "Unknown read status"
          end
        end
      end

      if group_warnings.any?
        warn "WARNING: #{group_warnings.length}/#{group_requests.length} requests generated a warning for group: #{group.inspect}\n#{group_warnings.map { |w| "  #{w}" }.join("\n")}"
        total_warnings += group_warnings.length
      end
    end

    # Flag if we ever stop getting warnings, since that indicates better proxy
    # behavior and we can remove some of the error checks in this tests.
    assert_operator(total_warnings, :>, 0, "No warnings generated by test, but this is unexpected. Has proxy behavior changed? If so, verify if unexpected response logic can be removed.")
  ensure
    Ethon::Easy::Callbacks.class_variable_set(:@@debug_callback_exclude_types, [])
  end
end
