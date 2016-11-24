require "ipaddr"

module ApiUmbrellaTestHelpers
  module Setup
    extend ActiveSupport::Concern

    @@incrementing_unique_ip_addr = IPAddr.new("127.0.0.1")
    @@current_override_config = {}
    mattr_reader :api_user
    mattr_reader :api_key
    mattr_reader :http_options
    mattr_reader :keyless_http_options
    mattr_accessor :start_complete
    mattr_accessor :setup_complete
    mattr_accessor(:setup_mutex) { Mutex.new }
    mattr_accessor(:config_mutex) { Mutex.new }
    mattr_accessor(:config_set_mutex) { Mutex.new }
    mattr_accessor(:config_publish_mutex) { Mutex.new }

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
          ApiUmbrellaTestHelpers::Process.start
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

          ConfigVersion.delete_all
          ConfigVersion.publish!({
            "apis" => [
              {
                "_id" => "example",
                "frontend_host" => "127.0.0.1",
                "backend_host" => "127.0.0.1",
                "servers" => [
                  { "host" => "127.0.0.1", "port" => 9444 },
                ],
                "url_matches" => [
                  { "frontend_prefix" => "/api/", "backend_prefix" => "/" },
                ],
              },
            ],
          }).wait_until_live

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
          @@keyless_http_options = @@http_options.except(:headers).freeze

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
      @prepend_api_backends_counter ||= 0
      apis.each do |api|
        @prepend_api_backends_counter += 1
        api["_id"] = "#{unique_test_id}-#{@prepend_api_backends_counter}"
      end

      publish_backends("apis", apis)

      yield if(block_given?)
    ensure
      if(block_given?)
        unpublish_backends("apis", apis)
      end
    end

    def prepend_website_backends(websites)
      @prepend_website_backends_counter ||= 0
      websites.each do |website|
        @prepend_website_backends_counter += 1
        website["_id"] = "#{unique_test_id}-#{@prepend_website_backends_counter}"
      end

      publish_backends("website_backends", websites)

      yield if(block_given?)
    ensure
      if(block_given?)
        unpublish_backends("website_backends", websites)
      end
    end

    def publish_backends(type, records)
      self.config_publish_mutex.synchronize do
        config = ConfigVersion.active_config || {}
        config[type] = records + (config[type] || [])
        ConfigVersion.publish!(config).wait_until_live
      end
    end

    def unpublish_backends(type, records)
      self.config_publish_mutex.synchronize do
        record_ids = records.map { |record| record["_id"] }
        config = ConfigVersion.active_config || {}
        config[type].reject! { |record| record_ids.include?(record["_id"]) }
        ConfigVersion.publish!(config).wait_until_live
      end
    end

    def override_config(config, reload_flag)
      self.config_mutex.synchronize do
        original_config = @@current_override_config
        original_config["version"] ||= SecureRandom.uuid

        begin
          override_config_set(config, reload_flag)
          yield
        ensure
          override_config_set(original_config, reload_flag)
        end
      end
    end

    def override_config_set(config, reload_flag)
      self.config_set_mutex.synchronize do
        config = config.deep_stringify_keys
        config["version"] = SecureRandom.uuid
        File.write(ApiUmbrellaTestHelpers::Process::CONFIG_OVERRIDES_PATH, YAML.dump(config))
        ApiUmbrellaTestHelpers::Process.reload(reload_flag)
        @@current_override_config = config
        ApiUmbrellaTestHelpers::Process.wait_for_config_version("file_config_version", config["version"], config)
      end
    end

    def override_config_reset(reload_flag)
      override_config_set({}, reload_flag)
    end

    def unique_test_class_id
      @unique_test_class_id ||= self.class.name
    end

    def unique_test_id
      @unique_test_id ||= self.location.gsub(/[^\w]/, "-")
    end

    def next_unique_ip_addr
      @@incrementing_unique_ip_addr = @@incrementing_unique_ip_addr.succ
      @@incrementing_unique_ip_addr.to_s
    end

    def unique_test_ip_addr
      unless @unique_test_ip_addr
        @unique_test_ip_addr = next_unique_ip_addr
      end

      @unique_test_ip_addr
    end
  end
end
