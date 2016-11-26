require_relative "../test_helper"

class Test::Processes::TestNetworkBinds < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_quick_timeout_when_backends_down
    pid_path = File.join($config["run_dir"], "perpboot.pid")
    output, status = Open3.capture2e("lsof -n -P -l -R -p $(pstree -p $(cat #{pid_path}) | grep -o '([0-9]\\+)' | grep -o '[0-9]\\+' | tr '\\012' ',') | grep LISTEN")
    assert_equal(0, status, output)

    listening = {
      :local => Set.new,
      :public => Set.new,
    }
    output.strip.split("\n").each do |line|
      ip_version = line.match(/(IPv4|IPv6)/)[1]
      assert(ip_version, line)

      port = line.match(/:(\d+) \(LISTEN\)/)[1]
      assert(port, line)

      listen = "#{port}:#{ip_version}"
      if(line.include?("TCP 127.0.0.1:") || line.include?("TCP [::1]:"))
        listening[:local] << listen
      elsif(line.include?("TCP *:"))
        listening[:public] << listen
      else
        raise "Unknown listening (not localhost or public): #{line.inspect}"
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
    assert_operator(listening[:local].length, :>, 0)
  end
end
