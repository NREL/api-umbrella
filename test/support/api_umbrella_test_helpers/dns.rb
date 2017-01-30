module ApiUmbrellaTestHelpers
  module Dns
    # When checking to make sure we adhere to TTLs on the domain names, add a
    # buffer to our timing calculations. This is to account for some fuzziness in
    # our timings between what's happening in nginx and our test requests being
    # made.
    TTL_BUFFER_NEG = 1.6
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

    def set_dns_records(records) # rubocop:disable Style/AccessorMethodName
      @custom_dns_records_set_during_this_test = true
      unbound_config_path = File.join($config["root_dir"], "etc/test-env/unbound/active_test.conf")
      content = records.map { |r| "local-data: '#{r}'" }.join("\n")
      File.open(unbound_config_path, "w") { |f| f.write(content) }

      output, status = run_shell("perpctl -b #{File.join($config["root_dir"], "etc/perp")} hup test-env-unbound")
      assert_equal(0, status, output)
    end

    def wait_for_response(path, options)
      begin
        Timeout.timeout(15) do
          loop do
            response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options)
            if(response.code == options.fetch(:code))
              if(options[:local_interface_ip])
                assert_response_code(200, response)
                data = MultiJson.load(response.body)
                if(options[:local_interface_ip] == data["local_interface_ip"])
                  break
                end
              else
                break
              end
            end

            sleep 0.1
          end
        end
      rescue Timeout::Error
        flunk("DNS change not detected")
      end

      # After we detect the change we want, wait an additional 500ms. This is
      # to handle the fact that even though we've seen the desired state, it
      # may take some additional time before this update has propagated to all
      # nginx workers. This is due to how dyups works, so we must wait a bit
      # longer than the configured dyups_read_msg_timeout time.
      sleep 0.5
    end
  end
end
