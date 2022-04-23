require_relative "../test_helper"

class Test::Processes::TestConfig < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_migrates_legacy_cached_values
    legacy_path = File.join($config["run_dir"], "cached_random_config_values.yml")
    new_path = File.join($config["run_dir"], "cached_random_config_values.json")
    new_path_backup = File.join($config["run_dir"], "cached_random_config_values.json.backup")

    legacy_config = {
      "secret_key" => "#{unique_test_id}-#{SecureRandom.uuid}",
      "static_site" => {
        "api_key" => "#{unique_test_id}-#{SecureRandom.uuid}",
      },
    }

    prior_runtime_config = MultiJson.load(File.read(File.join($config["run_dir"], "runtime_config.json")))
    refute_equal(legacy_config.fetch("secret_key"), prior_runtime_config.fetch("secret_key"))
    refute_equal(legacy_config.fetch("static_site").fetch("api_key"), prior_runtime_config.fetch("static_site").fetch("api_key"))

    begin
      FileUtils.mv(new_path, new_path_backup)

      refute(File.exist?(legacy_path))
      refute(File.exist?(new_path))

      File.write(legacy_path, YAML.dump(legacy_config))

      assert(File.exist?(legacy_path))
      refute(File.exist?(new_path))

      api_umbrella_process.reload

      refute(File.exist?(legacy_path))
      assert(File.exist?(new_path))

      runtime_config = MultiJson.load(File.read(File.join($config["run_dir"], "runtime_config.json")))
      assert_equal(legacy_config.fetch("secret_key"), runtime_config.fetch("secret_key"))
      assert_equal(legacy_config.fetch("static_site").fetch("api_key"), runtime_config.fetch("static_site").fetch("api_key"))
    ensure
      FileUtils.rm_f([legacy_path, new_path])
      FileUtils.mv(new_path_backup, new_path)
      api_umbrella_process.reload

      refute(File.exist?(legacy_path))
      assert(File.exist?(new_path))

      runtime_config = MultiJson.load(File.read(File.join($config["run_dir"], "runtime_config.json")))
      assert_equal(prior_runtime_config, runtime_config)
    end
  end
end
