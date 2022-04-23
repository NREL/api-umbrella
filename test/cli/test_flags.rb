require_relative "../test_helper"

class Test::Cli::TestFlags < Minitest::Test
  def test_version
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "--version")
    assert_equal("#{File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip}\n", stdout)
    assert_equal("", stderr)
    assert_equal(0, status.exitstatus)
  end

  def test_help_short
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "-h")
    assert_match(/Show this help message and exit/, stdout)
    assert_equal("", stderr)
    assert_equal(0, status.exitstatus)
  end

  def test_help_long
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "--help")
    assert_match(/Show this help message and exit/, stdout)
    assert_equal("", stderr)
    assert_equal(0, status.exitstatus)
  end

  def test_unknown_flag
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "--foobar")
    assert_equal("", stdout)
    assert_equal("Usage: api-umbrella [-h] [--version] <command> ...\n\nError: unknown option '--foobar'\n", stderr)
    assert_equal(1, status.exitstatus)
  end
end
