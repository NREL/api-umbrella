require_relative "../test_helper"

class Test::Processes::TestNetworkBinds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Lsof

  def setup
    super
    setup_server
  end

  def test_binds_http_to_public_interface_other_services_to_localhost
    files = lsof("-i", "TCP", "-s", "TCP:LISTEN")

    listening = {
      :local => Set.new,
      :local_ports => Set.new,
      :public => Set.new,
    }
    files.each do |file|
      assert_equal("TCP", file.fetch(:protocol))

      ip_version = file.fetch(:type)
      assert_includes(["IPv4", "IPv6"], ip_version)

      port = file.fetch(:file).match(/:(\d+)/)[1]
      assert(port, file)

      listen = "#{port}:#{ip_version}"
      if(file.fetch(:file).start_with?("127.0.0.1:", "[::1]:"))
        listening[:local] << listen
        listening[:local_ports] << port.to_i
      elsif(file.fetch(:file).start_with?("*:"))
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
    ].sort, listening[:public].sort)

    # Ensure all other services are listening on localhost-only, and sanity
    # check to ensure some of the expected services were present in the lsof
    # output.
    assert_operator(listening[:local].length, :>, 0)
    assert_operator(listening[:local_ports].length, :>, 0)
    assert_includes(listening[:local_ports], $config.fetch("trafficserver").fetch("port"))
  end
end
