RSpec.configure do |config|
  # If we're explicitly running the Rails test suite as part of the integration
  # tests, do things a bit differently, and startup the databases as separate
  # processes via the normal API Umbrella start command.
  #
  # This ensures that everything is compatible with the actual bundled versions
  # of the database servers and is similar to how we startup API Umbrella as a
  # sub-process of the tests in the other npm integration tests.
  if(ENV["INTEGRATION_TEST_SUITE"])
    # rubocop:disable Style/GlobalVars
    config.before(:suite) do
      root = File.expand_path("../../../../../../", __FILE__)
      embedded_root = File.join(root, "build/work/stage/opt/api-umbrella/embedded")

      # Pull in the test.yml config file used in all the other npm integration
      # tests. Alter to prevent running of the web app (since that's what we're
      # testing here, so it doesn't need to be spun up), and for these test
      # purposes, just connect to the single mongodb instance (not the
      # replicaset the npm tests run against).
      config = YAML.load_file(File.join(root, "test/config/test.yml"))
      config["services"] = ["general_db", "log_db", "router"]
      config["mongodb"]["url"] = "mongodb://127.0.0.1:13001/api_umbrella_test"
      config_path = Rails.root.join("tmp/integration_test_suite.yml")
      File.write(config_path, YAML.dump(config))

      # Spin up API Umbrella and the embedded databases as a background
      # process.
      $api_umbrella_process = ChildProcess.build(File.join(root, "bin/api-umbrella"), "run")
      $api_umbrella_process.io.inherit!
      $api_umbrella_process.environment["API_UMBRELLA_EMBEDDED_ROOT"] = embedded_root
      $api_umbrella_process.environment["API_UMBRELLA_CONFIG"] = config_path
      $api_umbrella_process.start

      # Run the health command to wait for API Umbrella to fully startup.
      health = ChildProcess.build(File.join(root, "bin/api-umbrella"), "health", "--wait-for-status", "green", "--wait-timeout", "90")
      health.io.inherit!
      health.environment["API_UMBRELLA_EMBEDDED_ROOT"] = embedded_root
      health.environment["API_UMBRELLA_CONFIG"] = config_path
      health.start
      health.wait

      # If anything exited unsuccessfully, abort tests.
      if(health.crashed? || $api_umbrella_process.crashed?)
        raise "Did not start api-umbrella process for integration tests"
      end
    end

    config.after(:suite) do
      if($api_umbrella_process && $api_umbrella_process.alive?)
        $api_umbrella_process.stop
      end
    end
    # rubocop:enable Style/GlobalVars
  end
end
