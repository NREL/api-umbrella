require "ipaddr"

module ApiUmbrellaTests
  module Setup
    extend ActiveSupport::Concern

    @@incrementing_unique_ip_addr = IPAddr.new("127.0.0.1")
    mattr_reader :api_user
    mattr_reader :api_key
    mattr_reader :http_options
    mattr_accessor :start_complete
    mattr_accessor :setup_complete
    mattr_accessor(:setup_mutex) { Mutex.new }
    mattr_accessor(:config_mutex) { Mutex.new }
    mattr_accessor(:config_set_mutex) { Mutex.new }
    mattr_accessor(:api_config_mutex) { Mutex.new }

    included do
      mattr_accessor :class_setup_complete
      mattr_accessor(:class_setup_mutex) { Mutex.new }
    end

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
      self.setup_mutex.synchronize do
        unless self.start_complete
          # Start the API Umbrella process to test against.
          ApiUmbrellaTests::Process.start
          self.start_complete = true
        end
      end

      super
    end

    private

    def setup_server
      self.setup_mutex.synchronize do
        unless self.setup_complete
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

          require "typhoeus/adapters/faraday"
          client = Elasticsearch::Client.new({
            :hosts => $config["elasticsearch"]["hosts"],
          })
          Elasticsearch::Persistence.client = client

          # For simplicity sake, we're assuming our tests only deal with a few explicit
          # indexes currently.
          ["2014-11", "2015-01", "2015-03"].each do |month|
            # First delete any existing indexes.
            ["api-umbrella-logs-v1-#{month}", "api-umbrella-logs-#{month}", "api-umbrella-logs-write-#{month}"].each do |index_name|
              begin
                client.indices.delete :index => index_name
              rescue Elasticsearch::Transport::Transport::Errors::NotFound # rubocop:disable Lint/HandleExceptions
              end
            end

            # Create the index with proper aliases setup.
            client.indices.create(:index => "api-umbrella-logs-v1-#{month}", :body => {
              :aliases => {
                "api-umbrella-logs-#{month}" => {},
                "api-umbrella-logs-write-#{month}" => {},
              },
            })
          end

          ApiUmbrellaTests::ConfigVersion.delete_all
          ApiUmbrellaTests::ConfigVersion.insert_default

          ApiUser.where(:registration_source.ne => "seed").delete_all
          user = FactoryGirl.create(:api_user, {
            :registration_source => "seed",
            :settings => {
              :rate_limit_mode => "unlimited",
            },
          })

          @@api_user = user
          @@api_key = user["api_key"]
          @@http_options = {
            # Disable SSL verification by default, since most of our tests are
            # against our self-signed SSL certificate for the test environment.
            :ssl_verifypeer => false,

            # When sending x-www-form-urlencoded encoded bodies, serialize Ruby
            # arrays the way Rails expects
            # (https://github.com/typhoeus/ethon/pull/104).
            :params_encoding => :rack,

            :headers => {
              "X-Api-Key" => user["api_key"],
            }.freeze,
          }.freeze

          self.setup_complete = true
        end
      end
    end

    def once_per_class_setup
      unless self.class_setup_complete
        self.class_setup_mutex.synchronize do
          unless self.class_setup_complete
            yield
            self.class_setup_complete = true
          end
        end
      end
    end

    def prepend_api_backends(apis)
      apis.each_with_index do |apis, index|
        apis["_id"] = "#{unique_test_id}-#{index}"
      end

      self.api_config_mutex.synchronize do
        config_version = ApiUmbrellaTests::ConfigVersion.get
        config_version["config"]["apis"] = apis + config_version["config"]["apis"]
        ApiUmbrellaTests::ConfigVersion.insert(config_version)
      end

      yield if(block_given?)
    ensure
      if(block_given?)
        self.api_config_mutex.synchronize do
          api_ids = apis.map { |api| api["_id"] }
          config_version = ApiUmbrellaTests::ConfigVersion.get
          config_version["config"]["apis"].reject! { |api| api_ids.include?(api["_id"]) }
          ApiUmbrellaTests::ConfigVersion.insert(config_version)
        end
      end
    end

    def override_config(config, reload_flag)
      self.config_mutex.synchronize do
        begin
          override_config_set(config, reload_flag)
          yield
        ensure
          override_config_reset(reload_flag)
        end
      end
    end

    def override_config_set(config, reload_flag)
      self.config_set_mutex.synchronize do
        config["version"] = SecureRandom.uuid
        File.write("/tmp/integration_test_suite_overrides.yml", YAML.dump(config))
        ApiUmbrellaTests::Process.reload(reload_flag)
        ApiUmbrellaTests::Process.wait_for_config_version("file_config_version", config["version"], config)
      end
    end

    def override_config_reset(reload_flag)
      self.config_set_mutex.synchronize do
        File.write("/tmp/integration_test_suite_overrides.yml", YAML.dump({ "version" => 0 }))
        ApiUmbrellaTests::Process.reload(reload_flag)
        ApiUmbrellaTests::Process.wait_for_config_version("file_config_version", 0)
      end
    end

    def unique_test_class_id
      @unique_test_class_id ||= self.class.name
    end

    def unique_test_id
      @unique_test_id ||= "#{self.location.gsub(/[^\w]/, "-")}"
    end

    def unique_test_ip_addr
      unless @unique_test_ip_addr
        @@incrementing_unique_ip_addr = @@incrementing_unique_ip_addr.succ
        @unique_test_ip_addr ||= @@incrementing_unique_ip_addr.to_s
      end

      @unique_test_ip_addr
    end
  end
end
