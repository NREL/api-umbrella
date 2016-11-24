require_relative "../test_helper"

class Test::Proxy::TestConfig < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    setup_server
  end

  def test_overrides_default_null_value
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert_equal(nil, default_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])

    expected_test_value = {
      "host" => "127.0.0.1",
      "method" => "plain",
      "uid" => "sAMAccountName",
      "base" => "dc=example,dc=com",
      "port" => 389,
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])

    runtime_config = YAML.load_file(File.join($config["root_dir"], "var/run/runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])
  end
end
