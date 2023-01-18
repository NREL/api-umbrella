require_relative "../test_helper"

class Test::Cli::TestCommands < Minitest::Test
  def test_version
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "version")
    assert_equal("#{File.read(File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/version.txt")).strip}\n", stdout)
    assert_equal("", stderr)
    assert_equal(0, status.exitstatus)
  end

  def test_help
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "help")
    assert_match(/Show this help message and exit/, stdout)
    assert_equal("", stderr)
    assert_equal(0, status.exitstatus)
  end

  def test_unknown_command
    stdout, stderr, status = Open3.capture3(ApiUmbrellaTestHelpers::Process.instance.test_environment_variables, File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "foobar")
    assert_equal("", stdout)
    assert_equal("Usage: api-umbrella [-h] [--version] <command> ...\n\nError: unknown command 'foobar'\n", stderr)
    assert_equal(1, status.exitstatus)
  end
end
