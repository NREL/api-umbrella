module ApiUmbrellaTestHelpers
  module Dns
    # When checking to make sure we adhere to TTLs on the domain names, add a
    # buffer to our timing calculations. This is to account for some fuzziness in
    # our timings between what's happening in nginx and our test requests being
    # made.
    TTL_BUFFER_NEG = 1.8
    TTL_BUFFER_POS = 2.1

    def teardown
      super
      if(@custom_dns_records_set_during_this_test)
        # Remove any custom DNS entries to prevent rapid reloads (for short TTL
        # records) after these DNS tests finish.
        set_dns_records([])
      end
    end

    private

    def set_dns_records(records, options = [])
      @custom_dns_records_set_during_this_test = true
      unbound_config_path = File.join($config["root_dir"], "etc/test-env/unbound/active_test.conf")
      content = (records.map { |r| "local-data: '#{r}'" } + options).join("\n")
      File.write(unbound_config_path, content)

      api_umbrella_process.perp_signal("test-env-unbound", "hup")
    end

    def wait_for_response(path, options)
      response = nil
      data = nil
      Timeout.timeout(15) do
        loop do
          response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
          matched = false
          if(response.code == options.fetch(:code))
            matched = true
          end

          if matched && options[:local_interface_ip]
            matched = false
            assert_response_code(200, response)
            data = MultiJson.load(response.body)
            if(options[:local_interface_ip] == data["local_interface_ip"])
              matched = true
            end
          end

          if matched && options[:body]
            matched = false
            if options[:body].match(response.body)
              matched = true
            end
          end

          if matched
            break
          end

          sleep 0.1
        end
      end

      response
    rescue Timeout::Error
      message = <<~EOS
        DNS change not detected:

        Expected response code: #{options.fetch(:code)}
        Actual response code: #{response.code if(response)}

        Expected DNS resolve to: #{options[:local_interface_ip]}
        Actual DNS resolve to: #{data["local_interface_ip"] if(data)}

        Last response:
        #{response_error_message(response)}
      EOS
      flunk(message)
    end
  end
end
