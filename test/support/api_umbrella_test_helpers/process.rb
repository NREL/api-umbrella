require "ipaddr"

module ApiUmbrellaTestHelpers
  class Process
    EMBEDDED_ROOT = File.join(API_UMBRELLA_SRC_ROOT, "build/work/stage/opt/api-umbrella/embedded").freeze
    TEST_RUN_ROOT = File.join(API_UMBRELLA_SRC_ROOT, "test/tmp/run")
    TEST_RUN_API_UMBRELLA_ROOT = File.join(TEST_RUN_ROOT, "api-umbrella-root")
    CONFIG_PATH = File.join(API_UMBRELLA_SRC_ROOT, "config/test.yml").freeze
    CONFIG_COMPUTED_PATH = File.join(TEST_RUN_ROOT, "test_computed.yml").freeze
    CONFIG_OVERRIDES_PATH = File.join(TEST_RUN_ROOT, "test_overrides.yml").freeze
    CONFIG = "#{CONFIG_PATH}:#{CONFIG_COMPUTED_PATH}:#{CONFIG_OVERRIDES_PATH}".freeze
    @@incrementing_unique_ip_addr = IPAddr.new("200.0.0.1")

    def self.start
      Minitest.after_run do
        ApiUmbrellaTestHelpers::Process.stop
      end

      start_time = Time.now.utc
      FileUtils.rm_rf(Dir.glob(File.join(TEST_RUN_ROOT, "*"), File::FNM_DOTMATCH) - [File.join(TEST_RUN_ROOT, "."), File.join(TEST_RUN_ROOT, "..")])
      FileUtils.mkdir_p(TEST_RUN_API_UMBRELLA_ROOT)

      original_env = ENV.to_hash
      begin
        # Wipe any bundler environment variables before executing sub-shells to
        # prevent confusion between the test bundler environment and the
        # web-app's bundler environment.
        #
        # We're manually removing all these rather than using
        # Bundler.with_clean_env or with_original_env, since those don't quite
        # work for our case. Bundler's approach restores the original
        # environment, which omits any ENV customizations we may have actually
        # intended. It also doesn't work quite right since Rake::TestTask
        # triggers these scripts via a ruby system() call, so there's multiple
        # layers of shells, which confuses what's the "original" environment.
        ENV.delete_if { |key, value| key =~ /\A(GEM_|BUNDLE_|BUNDLER_|RUBY)/ }

        # Read the initial test config file.
        $config = YAML.load_file(CONFIG_PATH)

        # Create an config file for computed overrides.
        computed = {
          "root_dir" => TEST_RUN_API_UMBRELLA_ROOT,
        }
        File.write(CONFIG_COMPUTED_PATH, YAML.dump(computed))
        $config.deep_merge!(YAML.load_file(CONFIG_COMPUTED_PATH))

        # Create an empty config file for test-specific overrides.
        File.write(CONFIG_OVERRIDES_PATH, YAML.dump({ "version" => 0 }))

        # Trigger a build to ensure the tests get run with the latest
        # environment. This takes care of tasks in the sub-components, like
        # bundling new dependencies, or recompiling the javascript files.
        build = ChildProcess.build("make")
        build.io.inherit!
        build.cwd = API_UMBRELLA_SRC_ROOT
        build.start
        build.wait
        if(build.crashed?)
          exit build.exit_code
        end

        # Spin up API Umbrella and the embedded databases as a background
        # process.
        $api_umbrella_process = ChildProcess.build(File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "run")
        $api_umbrella_process.io.inherit!
        $api_umbrella_process.environment["API_UMBRELLA_EMBEDDED_ROOT"] = EMBEDDED_ROOT
        $api_umbrella_process.environment["API_UMBRELLA_CONFIG"] = CONFIG
        $api_umbrella_process.leader = true
        $api_umbrella_process.start

        # Run the health command to wait for API Umbrella to fully startup.
        health = ChildProcess.build(File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "health", "--wait-for-status", "green", "--wait-timeout", "90")
        health.io.inherit!
        health.environment["API_UMBRELLA_EMBEDDED_ROOT"] = EMBEDDED_ROOT
        health.environment["API_UMBRELLA_CONFIG"] = CONFIG
        health.start

        progress = Thread.new do
          print "Waiting for api-umbrella to start..."
          loop do
            if($api_umbrella_process.crashed?)
              health.stop
              break
            end

            print "."
            sleep 2
          end
        end

        health.wait
        progress.exit

        end_time = Time.now.utc
        puts format("(%.2fs)", end_time - start_time)

        # If anything exited unsuccessfully, abort tests.
        if(health.crashed? || $api_umbrella_process.crashed?)
          raise "Did not start api-umbrella process for integration tests"
        end

        # Once API Umbrella is started, read the config from the runtime file.
        # This allows the tests to access the full config (accounting for
        # merging config from multiple sources and any computed config
        # settings).
        runtime_config_path = File.join($config["root_dir"], "var/run/runtime_config.yml")
        unless(File.exist?(runtime_config_path))
          raise "runtime_config.yml file not found after starting: #{runtime_config_path.inspect}"
        end
        $config = YAML.load_file(runtime_config_path)
      ensure
        # Restore the original environment before we wiped the bundler
        # variables.
        ENV.replace(original_env)
      end

    # If anything fails during API Umbrella's startup, make sure we attempt to
    # stop the API Umbrella process, so we don't leave processes hanging
    # around.
    #
    # This is also a case where we do want to rescue the low-level Exception
    # class to ensure we have a chance to properly stop the child process on
    # things like SIGINTs.
    rescue Exception => e # rubocop:disable Lint/RescueException
      puts "Error occurred while starting api-umbrella, stopping..."
      puts e.message
      puts e.backtrace.join("\n")

      self.stop
      raise e
    end

    def self.stop
      if($api_umbrella_process && $api_umbrella_process.alive?)
        puts "Stopping api-umbrella..."

        begin
          stop = ChildProcess.build(File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "stop")
          stop.io.inherit!
          stop.environment["API_UMBRELLA_EMBEDDED_ROOT"] = EMBEDDED_ROOT
          stop.environment["API_UMBRELLA_CONFIG"] = CONFIG
          stop.start
          stop.wait

          if(stop.exit_code != 0)
            raise "api-umbrella failed to stop"
          end
        ensure
          $api_umbrella_process.stop
        end
      end
    end

    def self.reload(flag)
      reload = ChildProcess.build(*[File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella"), "reload", flag].flatten.compact)
      reload.io.inherit!
      reload.environment["API_UMBRELLA_EMBEDDED_ROOT"] = EMBEDDED_ROOT
      reload.environment["API_UMBRELLA_CONFIG"] = CONFIG
      reload.start
      reload.wait
    end

    def self.restart_trafficserver
      reload = ChildProcess.build(*[File.join(API_UMBRELLA_SRC_ROOT, "bin/api-umbrella-exec"), "perpctl", "-b", File.join($config["root_dir"], "etc/perp"), "-q", "term", "trafficserver"].flatten.compact)
      reload.io.inherit!
      reload.environment["API_UMBRELLA_EMBEDDED_ROOT"] = EMBEDDED_ROOT
      reload.environment["API_UMBRELLA_CONFIG"] = CONFIG
      reload.start
      reload.wait

      # Sleep to ensure that the traffiserver kill signal is received and it's
      # had a chance to die, before moving onto the health checks (so we don't
      # check the health before the server has actually been killed).
      sleep 1

      # After killing and restarting trafficserver, wait for it to come back
      # online (since this full restart isn't a normal occurrence and will
      # incur downtime).
      #
      # Note that we're currently doing this to reload DNS changes within
      # Traffic Server. We could also call `traffic_ctl server restart` which
      # just restarts the traffic_server process (and not the manager), which
      # appears to work without any downtime. However, while DNS changes are
      # picked up after that type of restart, it's hard to predict when those
      # changes are fully live within trafficserver, so that's why we[re opting
      # for this full restart to handle DNS changes in the test suite (in real
      # live, DNS server changes shouldn't be likely, though, so this is mainly
      # a test environment issue).
      begin
        Timeout.timeout(40) do
          loop do
            response = Typhoeus.get("http://127.0.0.1:9080/api-umbrella/v1/health?#{rand}")
            if(response.code == 200)
              break
            end

            sleep 0.1
          end
        end
      rescue Timeout::Error
        raise Timeout::Error, "API Umbrella configuration changes were not detected. Waiting for version #{version}. Last seen: #{state.inspect} #{health.inspect}"
      end
    end

    def self.wait_for_config_version(field, version, config = {})
      state = nil
      health = nil
      begin
        # Reloading is normally fast, but can sometimes be slower if the
        # web-app is being reloaded and we have to wait for it to become
        # healthy again.
        Timeout.timeout(40) do
          loop do
            state = self.fetch("http://127.0.0.1:9080/api-umbrella/v1/state?#{rand}", config)
            if(state[field] == version)
              health = self.fetch("http://127.0.0.1:9080/api-umbrella/v1/health?#{rand}", config)
              if(health["status"] == "green")
                break
              end
            end

            sleep 0.1
          end
        end
      rescue Timeout::Error
        raise Timeout::Error, "API Umbrella configuration changes were not detected. Waiting for version #{version}. Last seen: #{state.inspect} #{health.inspect}"
      end
    end

    def self.fetch(url, config)
      http_opts = {}

      # If we're performing global rate limit tests, use a different IP address
      # for each internal API request when trying to determine if the config is
      # published. This prevents us from accidentally hitting these global rate
      # limits in our rapid polling requests to determine if things are ready.
      if(config && config["router"] && config["router"]["global_rate_limits"])
        @@incrementing_unique_ip_addr = @@incrementing_unique_ip_addr.succ
        http_opts.deep_merge!({
          :headers => {
            "X-Forwarded-For" => @@incrementing_unique_ip_addr.to_s,
          },
        })
      end

      response = Typhoeus.get(url, http_opts)
      begin
        data = MultiJson.load(response.body)
      rescue MultiJson::ParseError => e
        raise MultiJson::ParseError, "#{e.message}: #{url} failure (#{response.code}): #{response.body}"
      end

      data
    end
  end
end
