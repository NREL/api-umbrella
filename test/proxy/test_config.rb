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
    assert_nil(default_config.fetch("_test_config").fetch("default_null_override_hash"))

    expected_test_value = {
      "foo" => "bar",
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_null_override_hash"))

    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_null_override_hash"))
  end

  def test_overrides_default_null_value_with_string
    assert_nil(default_config.fetch("_test_config").fetch("default_null_override_string"))

    expected_test_value = "foobar"

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_null_override_string"))

    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_null_override_string"))
  end

  def test_overrides_default_empty_hash_value
    assert_equal({}, default_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))

    expected_test_value = {
      "baz" => "qux",
    }

    test_config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml"))
    assert_equal(expected_test_value, test_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))

    assert_equal(expected_test_value, runtime_config.fetch("_test_config").fetch("default_empty_hash_override_hash"))
  end

  private

  def default_config
    unless @default_config
      output, status = Open3.capture2(
        "cue",
        "export",
        "--out", "json",
        "--inject", "src_root_dir=/dummy",
        "--inject", "embedded_root_dir=/dummy",
        File.join(API_UMBRELLA_SRC_ROOT, "config/schema.cue")
      )
      unless status.success?
        raise "Error: Database setup failed:\n\n#{output}"
      end

      @default_config = MultiJson.load(output)
    end

    @default_config
  end

  def runtime_config
    MultiJson.load(File.read(File.join($config["run_dir"], "runtime_config.json")))
  end
end
