module ApiUmbrellaTests
  module Setup
    @@semaphore = Mutex.new
    @@start_complete = false
    @@setup_complete = false

    # Start the API Umbrella server process before any tests run.
    #
    # We perform this before the #run phase (rather than in the more normal
    # #setup phase) so that the time spent starting up doesn't get counted as
    # part of the first test being run (which would skew the metrics for
    # individual test times). This also occurs later than directly inside
    # test_helper.rb so that we're sure minitest will actually run (for
    # example, no invalid command line flags given) and this includes the
    # startup time in the overall test times (just not any individual test
    # times).
    def run
      @@semaphore.synchronize do
        unless @@start_complete
          # Start the API Umbrella process to test against.
          ApiUmbrellaTests::Process.start
          @@start_complete = true
        end
      end

      super
    end

    def setup_server
      @@semaphore.synchronize do
        unless @@setup_complete
          Mongoid.load_configuration({
            "clients" => {
              "default" => {
                "uri" => $config["mongodb"]["url"],
                "options" => {
                  "max_pool_size" => 1,
                },
              },
            },
          })

          Admin.collection.drop
          ApiUmbrellaTests::ConfigVersion.delete_all
          ApiUmbrellaTests::ConfigVersion.insert_default

          ApiUmbrellaTests::User.delete_all
          user = ApiUmbrellaTests::User.insert

          @@http_options = {
            :headers => {
              "X-Api-Key" => user["api_key"],
            },
          }

          @@setup_complete = true
        end
      end
    end

    def prepend_api_backends(apis)
      apis.each_with_index do |apis, index|
        apis["_id"] = "#{self.location}-#{index}"
      end

      @@semaphore.synchronize do
        config_version = ApiUmbrellaTests::ConfigVersion.get
        config_version["config"]["apis"] = apis + config_version["config"]["apis"]
        ApiUmbrellaTests::ConfigVersion.insert(config_version)
      end

      yield
    ensure
      @@semaphore.synchronize do
        api_ids = apis.map { |api| api["_id"] }
        config_version = ApiUmbrellaTests::ConfigVersion.get
        config_version["config"]["apis"].reject! { |api| api_ids.include?(api["_id"]) }
        ApiUmbrellaTests::ConfigVersion.insert(config_version)
      end
    end

    def unique_url_prefix
      @unique_url_prefix ||= "#{self.location.gsub(/[^\w]/, "-")}"
    end
  end
end
