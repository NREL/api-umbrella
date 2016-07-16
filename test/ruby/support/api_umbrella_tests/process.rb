module ApiUmbrellaTests
  class Process
    def self.start
      Minitest.after_run do
        ApiUmbrellaTests::Process.stop
      end

      Bundler.with_clean_env do
        embedded_root = File.join(API_UMBRELLA_SRC_ROOT, "build/work/stage/opt/api-umbrella/embedded")

        $config = YAML.load_file(File.join(API_UMBRELLA_SRC_ROOT, "test/config/test.yml"))
        #config["services"] = ["general_db", "log_db", "router"]
        $config["mongodb"]["url"] = "mongodb://127.0.0.1:13001/api_umbrella_test"
        config_path = "/tmp/integration_test_suite.yml"
        File.write(config_path, YAML.dump($config))

        #config_path = File.join(API_UMBRELLA_SRC_ROOT, "test/config/test.yml")

        progress = Thread.new do
          print "Waiting for api-umbrella to start..."
          loop do
            print "."
            sleep 2
          end
        end

        # Spin up API Umbrella and the embedded databases as a background
        # process.
        $api_umbrella_process = ChildProcess.build(File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "run")
        $api_umbrella_process.io.inherit!
        $api_umbrella_process.environment["API_UMBRELLA_EMBEDDED_ROOT"] = embedded_root
        $api_umbrella_process.environment["API_UMBRELLA_CONFIG"] = config_path
        $api_umbrella_process.leader = true
        $api_umbrella_process.start

        # Run the health command to wait for API Umbrella to fully startup.
        health = ChildProcess.build(File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "health", "--wait-for-status", "green", "--wait-timeout", "90")
        health.io.inherit!
        health.environment["API_UMBRELLA_EMBEDDED_ROOT"] = embedded_root
        health.environment["API_UMBRELLA_CONFIG"] = config_path
        health.start
        health.wait

        progress.exit

        # If anything exited unsuccessfully, abort tests.
        if(health.crashed? || $api_umbrella_process.crashed?)
          raise "Did not start api-umbrella process for integration tests"
        end
      end
    rescue Exception => e
      self.stop
      raise e
    end

    def self.stop
      if($api_umbrella_process && $api_umbrella_process.alive?)
        $api_umbrella_process.stop
      end
    end
  end
end
