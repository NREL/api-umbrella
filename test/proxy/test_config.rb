require_relative "../test_helper"

class Test::Proxy::TestConfig < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  # Since lyaml reads in null values as a special object type, ensure that when
  # deep merging occurs, this null value gets overwritten by other object
  # types.
  def test_overrides_default_null_value_with_hash
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert(default_config["web"]["mailer"].key?("smtp_settings"))
    assert_nil(default_config["web"]["mailer"]["smtp_settings"])

    expected_test_value = {
      "address" => "127.0.0.1",
      "port" => 13102,
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config["web"]["mailer"]["smtp_settings"])

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config["web"]["mailer"]["smtp_settings"])
  end

  def test_overrides_default_null_value_with_string
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert(default_config["web"]["admin"]["auth_strategies"]["google"].key?("client_secret"))
    assert_nil(default_config["web"]["admin"]["auth_strategies"]["google"]["client_secret"])

    expected_test_value = "test_fake"

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config["web"]["admin"]["auth_strategies"]["google"]["client_secret"])

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config["web"]["admin"]["auth_strategies"]["google"]["client_secret"])
  end

  def test_overrides_default_empty_hash_value
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert_equal({}, default_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])

    expected_test_value = {
      "host" => "127.0.0.1",
      "method" => "plain",
      "uid" => "sAMAccountName",
      "base" => "dc=example,dc=com",
      "port" => 389,
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config["web"]["admin"]["auth_strategies"]["ldap"]["options"])
  end
end
