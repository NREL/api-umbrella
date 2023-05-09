IPV6_SUPPORT = (File.exist?("/proc/net/if_inet6") && !File.empty?("/proc/net/if_inet6"))

class Minitest::Test
  private

  def skip_unless_ipv6_support
    unless IPV6_SUPPORT
      message = "WARNING: Skipping test_static_ipv6 due to lack of IPv6 support."
      warn(message)
      skip(message)
    end
  end
end
