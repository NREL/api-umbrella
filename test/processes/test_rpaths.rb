require_relative "../test_helper"
require "find"

class Test::Processes::TestRpaths < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  # Ensure that any binaries have RPATH settings stripped before they're
  # installed. This ensures that the load path is always determined by
  # LD_LIBRARY_PATH, rather than whatever RPATH was set at compile time.
  #
  # This makes the installation path more relocatable, but also helps prevent
  # conflicts with the files installed in "build/work/stage" during
  # development/testing and the files in "/opt/api-umbrella." This primarily
  # impacts development and testing (since normal installations won't have
  # conflicting versions of things), but this helps ensure the staged binaries
  # always get picked up before system-wide binaries when running tests
  # (assuming LD_LIBRARY_PATH is set correctly). This helps prevent frustrating
  # debugging in development environments where both might be present. Since
  # this also makes the paths more configurable and relocatable, this also
  # seems like a decent approach for production purposes.
  def test_binary_rpaths
    # Find all the binaries.
    bins = Dir.glob(File.join($config["_embedded_root_dir"], "bin/**/*"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "sbin/**/*"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "lib/**/*.so"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "libexec/**/*.so"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "openresty/**/bin/**/*"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "openresty/**/sbin/**/*"))
    bins += Dir.glob(File.join($config["_embedded_root_dir"], "app/vendor/**/*.so"))
    bins.map! { |path| File.realpath(path) }
    bins.select! { |path| File.file?(path) }
    bins.reject! { |path| `file #{path}` =~ /(text executable|ASCII)/ }
    bins.sort!

    # Spot check to ensure our list of binaries actually includes things we
    # expect.
    assert_operator(bins.length, :>, 0)
    [
      "/embedded/bin/fluent-bit",
      "/embedded/openresty/nginx/sbin/nginx",
      "/embedded/libexec/trafficserver/header_rewrite.so",
      # LuaRock
      "/embedded/app/vendor/lua/lib/lua/5.1/yaml.so",
    ].each do |expected_path_end|
      assert(bins.find { |path| path.end_with?(expected_path_end) }, "Expected #{bins.inspect} to include #{expected_path_end.inspect}")
    end

    # Ensure each binary file has no rpath or runpath setting.
    bins.each do |path|
      output, _status = run_shell("chrpath", "-l", path)
      assert_match(/(no rpath or runpath tag found|No dynamic section found)/, output)
    end
  end
end
