require_relative "../test_helper"

class Test::Processes::TestNetworkBinds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_binds_http_to_public_interface_other_services_to_localhost
    pid = File.read(File.join($config["run_dir"], "perpboot.pid")).strip
    pstree_output, pstree_status = run_shell("pstree -p #{pid}")
    assert_equal(0, pstree_status, pstree_output)
    pids = pstree_output.scan(/\((\d+)\)/).flatten.sort.uniq
    output, _status = run_shell("lsof -n -P -l -R -a -i TCP -s TCP:LISTEN -p #{pids.join(",")}")
    # lsof may return an unsuccessful exit code (since there may not be
    # anything to match for all the PIDs passed in), so just sanity check the
    # output.
    assert_match("COMMAND", output)

    listening = {
      :local => Set.new,
      :local_ports => Set.new,
      :public => Set.new,
    }
    output.strip.split("\n").each do |line|
      next if(line.start_with?("COMMAND"))

      ip_version = line.match(/(IPv4|IPv6)/)[1]
      assert(ip_version, line)

      port = line.match(/:(\d+) \(LISTEN\)/)[1]
      assert(port, line)

      listen = "#{port}:#{ip_version}"
      if(line.include?("TCP 127.0.0.1:") || line.include?("TCP [::1]:"))
        listening[:local] << listen
        listening[:local_ports] << port.to_i
      elsif(line.include?("TCP *:"))
        listening[:public] << listen
      else
        flunk("Unknown listening (not localhost or public): #{line.inspect}")
      end
    end

    assert_equal([
      # HTTP port in test environment.
      "9080:IPv4",
      "9080:IPv6",

      # HTTPS port in test environment.
      "9081:IPv4",
      "9081:IPv6",

      # API backend for our test environment that needs to listen on all
      # interfaces for some of our DNS tests that use 127.0.0.2,
      # 127.0.0.3, etc.
      "9444:IPv4",
      "9444:IPv6",
    ], listening[:public].sort)

    # Ensure all other services are listening on localhost-only, and sanity
    # check to ensure some of the expected services were present in the lsof
    # output.
    assert_operator(listening[:local].length, :>, 0)
    assert_operator(listening[:local_ports].length, :>, 0)
    assert_includes(listening[:local_ports], $config.fetch("elasticsearch").fetch("embedded_server_config").fetch("http").fetch("port"))
    assert_includes(listening[:local_ports], $config.fetch("mongodb").fetch("embedded_server_config").fetch("net").fetch("port"))
    assert_includes(listening[:local_ports], $config.fetch("mora").fetch("port"))
    assert_includes(listening[:local_ports], $config.fetch("trafficserver").fetch("port"))
  end
end
