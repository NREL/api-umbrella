require_relative "../test_helper"
require "find"

class Test::Processes::TestRpaths < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  # Ensure that any binaries that get compiled with rpath settings get compiled
  # with the build/work/stage path before the /opt/api-umbrella path. This is
  # to ensure that when running tests the staged binaries always get picked up
  # before any system-wide binaries. Setting up our rpaths this way helps
  # prevent weird debugging issues when you may have both a local build and a
  # system build during development.
  def test_binary_rpaths
    # Find all the binaries.
    bins = Find.find(File.join($config["_embedded_root_dir"], "bin")).to_a
    bins += Find.find(File.join($config["_embedded_root_dir"], "sbin")).to_a
    bins.map! { |path| File.realpath(path) }
    bins.select! { |path| File.file?(path) }
    bins.reject! { |path| `file #{path}` =~ /(text executable|ASCII)/ }

    # Spot check to ensure our list of binaries actually includes things we
    # expect.
    assert_operator(bins.length, :>, 0)
    assert(bins.find { |path| path.end_with?("embedded/openresty/nginx/sbin/nginx") })
    assert(bins.find { |path| path.end_with?("embedded/sbin/rsyslogd") })
    assert(bins.find { |path| path.end_with?("embedded/bin/ruby") })

    # Find the rpath of each binary.
    rpaths = []
    bins.each do |path|
      output, status = run_shell("readelf -d #{path}")
      assert_equal(0, status, "#{path}: #{output}: " + `file #{path}`)
      output.scan(/RPATH.*\[(.+?)\]/) do |rpath|
        rpaths += rpath
      end
    end

    rpaths.uniq!
    # Ensure that the rpaths have the local path listed before system paths.
    assert_equal([
      "#{File.join($config["_embedded_root_dir"], "lib")}:/opt/api-umbrella/embedded/lib",
      # OpenResty's nginx rpath also has the luajit path present.
      "#{File.join($config["_embedded_root_dir"], "openresty/luajit/lib")}:#{File.join($config["_embedded_root_dir"], "lib")}:/opt/api-umbrella/embedded/openresty/luajit/lib:/opt/api-umbrella/embedded/lib",
    ].sort, rpaths.sort)
  end
end
