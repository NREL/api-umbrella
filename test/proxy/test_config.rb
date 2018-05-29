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
    assert_nil(default_config.fetch("_test_config").fetch("default_null_override_hash"))

    expected_test_value = {
      "foo" => "bar",
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_null_override_hash"))

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_null_override_hash"))
  end

  def test_overrides_default_null_value_with_string
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert_nil(default_config.fetch("_test_config").fetch("default_null_override_string"))

    expected_test_value = "foobar"

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_null_override_string"))

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_null_override_string"))
  end

  def test_overrides_default_empty_hash_value
    default_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/default.yml"))
    assert_equal({}, default_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))

    expected_test_value = {
      "baz" => "qux",
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))

    runtime_config = YAML.load_file(File.join($config["run_dir"], "runtime_config.yml"))
    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))
  end
end
