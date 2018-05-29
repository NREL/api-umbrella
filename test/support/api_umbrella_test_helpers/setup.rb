require "English"
require "ipaddr"
require "support/api_umbrella_test_helpers/common_asserts"

module ApiUmbrellaTestHelpers
  module Setup
    extend ActiveSupport::Concern

    include ApiUmbrellaTestHelpers::CommonAsserts

    @@incrementing_unique_number = 0
    @@incrementing_unique_ip_addr = IPAddr.new("127.0.0.1")
    @@current_override_config = {}
    mattr_reader :api_user
    mattr_reader :api_key
    mattr_reader :http_options
    mattr_reader :keyless_http_options
    mattr_accessor :start_complete
    mattr_accessor :setup_complete
    mattr_accessor :setup_config_version_complete
    mattr_accessor :setup_api_user_complete
    mattr_accessor(:setup_mutex) { Mutex.new }
    mattr_accessor(:config_mutex) { Mutex.new }
    mattr_accessor(:config_set_mutex) { Mutex.new }
    mattr_accessor(:config_publish_mutex) { Mutex.new }
    mattr_accessor(:increment_mutex) { Mutex.new }

    included do
      mattr_accessor :unique_test_class_id_value
      mattr_accessor :unique_test_class_hostname_value
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
            :clients => {
              :default => {
                :uri => $config["mongodb"]["url"],
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
          ["2013-07", "2013-08", "2014-11", "2015-01", "2015-03"].each do |month|
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

          self.setup_complete = true
        end

        unless self.setup_config_version_complete
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
                  { "_id" => SecureRandom.uuid, "frontend_prefix" => "/api/", "backend_prefix" => "/" },
                ],
              },
            ],
          }).wait_until_live

          self.setup_config_version_complete = true
        end

        unless self.setup_api_user_complete
          ApiUser.where(:registration_source.ne => "seed").delete_all
          user = FactoryBot.create(:api_user, {
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
            :ssl_verifyhost => 0,

            # When sending x-www-form-urlencoded encoded bodies, serialize Ruby
            # arrays the way Rails expects
            # (https://github.com/typhoeus/ethon/pull/104).
            :params_encoding => :rack,

            :headers => {
              "X-Api-Key" => user["api_key"],
            }.freeze,
          }.freeze
          @@keyless_http_options = @@http_options.except(:headers).freeze

          self.setup_api_user_complete = true
        end
      end
    end

    # If tests need to delete all the ConfigVersion records from the database,
    # then they need to call this method after finishing so the default
    # ConfigVersion record will be re-created for other tests that depend on
    # it.
    def default_config_version_needed
      ApiUmbrellaTestHelpers::Setup.setup_mutex.synchronize do
        ApiUmbrellaTestHelpers::Setup.setup_config_version_complete = false
      end
    end

    # If tests need to delete all the ApiUser records from the database, then
    # they need to call this method after finishing so the default ApiUser
    # record will be re-created for other tests that depend on it.
    def default_api_user_needed
      ApiUmbrellaTestHelpers::Setup.setup_mutex.synchronize do
        ApiUmbrellaTestHelpers::Setup.setup_api_user_complete = false
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
      apis.map! do |api|
        api.deep_stringify_keys!

        @prepend_api_backends_counter += 1
        api["_id"] ||= "#{unique_test_id}-#{@prepend_api_backends_counter}"
        if(api["url_matches"])
          api["url_matches"].each do |url_match|
            url_match["_id"] ||= SecureRandom.uuid
          end
        end

        api
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
      websites.map! do |website|
        website.deep_stringify_keys!

        @prepend_website_backends_counter += 1
        website["_id"] = "#{unique_test_id}-#{@prepend_website_backends_counter}"

        website
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
        if(self.class.test_order == :parallel)
          raise "`override_config_set` cannot be called with `parallelize_me!` in the same class. Since overriding config affects the global state, it cannot be used with parallel tests."
        end

        previous_override_config = @@current_override_config.deep_dup

        config = config.deep_stringify_keys
        config["version"] = SecureRandom.uuid
        File.write(ApiUmbrellaTestHelpers::Process::CONFIG_OVERRIDES_PATH, YAML.dump(config))
        ApiUmbrellaTestHelpers::Process.reload(reload_flag)
        @@current_override_config = config
        ApiUmbrellaTestHelpers::Process.wait_for_config_version("file_config_version", config["version"], config)

        # When changes to the DNS server are made, this is one area where a
        # simple "reload" signal won't do the trick. Instead, we also need to
        # fully restart Traffic Server to pick up these changes (technically
        # there's ways to force Traffic Server to pick these changes up without
        # a full restart, but it's hard to figure out the timing, so with this
        # mainly being a test issue, we'll force a full restart).
        if(previous_override_config.dig("dns_resolver", "nameservers") || @@current_override_config.dig("dns_resolver", "nameservers"))
          ApiUmbrellaTestHelpers::Process.restart_trafficserver

        # When changing the keepalive idle timeout, a normal reload will pick
        # these changes up, but they don't kick in for a few seconds, which is
        # hard to time correctly in the test suite. So similarly, do a full
        # restart to make it easier to know for sure the new settings are in
        # effect.
        elsif(previous_override_config.dig("router", "api_backends", "keepalive_idle_timeout") || @@current_override_config.dig("router", "api_backends", "keepalive_idle_timeout"))
          ApiUmbrellaTestHelpers::Process.restart_trafficserver
        end
      end
    end

    def override_config_reset(reload_flag)
      override_config_set({}, reload_flag)
    end

    def to_unique_id(name)
      name.gsub(/[^\w]+/, "-")
    end

    def to_unique_hostname(name)
      # Replace all non alpha-numeric chars (namely underscores that might be
      # in the ID) with dashes (since underscores aren't valid for hostnames).
      hostname = name.downcase.gsub(/[^a-z0-9]+/, "-")

      # Truncate the hostname so the label will fit in unbound's 63 char limit.
      hostname = hostname[-56..-1] || hostname

      # Strip first char if it happens to be a dash.
      hostname.gsub!(/^-/, "")

      # Since we've truncated the test ID, it's possible it's no longer unique,
      # so append a unique number to the end (ensuring that it will fit within
      # the 63 char limit).
      unique_number = next_unique_number
      assert_operator(unique_number, :<=, 999999)
      hostname = "#{hostname}-#{unique_number.to_s.rjust(6, "0")}"

      "#{hostname}.test"
    end

    def unique_test_class_id
      self.unique_test_class_id_value ||= to_unique_id(self.class.name)
    end

    def unique_test_class_hostname
      self.unique_test_class_hostname_value ||= to_unique_hostname(unique_test_class_id)
    end

    def unique_test_id
      @unique_test_id ||= to_unique_id(self.location)
    end

    def unique_test_hostname
      @unique_test_hostname ||= to_unique_hostname(unique_test_id)
    end

    def next_unique_number
      self.increment_mutex.synchronize do
        @@incrementing_unique_number += 1
        @@incrementing_unique_number
      end
    end

    def next_unique_ip_addr
      self.increment_mutex.synchronize do
        @@incrementing_unique_ip_addr = @@incrementing_unique_ip_addr.succ
        @@incrementing_unique_ip_addr.to_s
      end
    end

    def unique_test_ip_addr
      @unique_test_ip_addr ||= next_unique_ip_addr
    end

    # Typheous/Ethon doesn't currently support sending empty HTTP headers by
    # simply setting the value to an empty string:
    # https://github.com/typhoeus/ethon/pull/132
    #
    # This provides a workaround by using a fake extra header (see
    # https://curl.haxx.se/mail/lib-2010-08/0174.html).
    #
    # If the Ethon pull request gets merged in, we can perhaps remove this, but
    # we may still need it if we want our test suite to run on CentOS 6 (where
    # curl is at v7.19, lacking the official support for sending empty values).
    def empty_http_header_options(header)
      @empty_http_header_counter ||= 0
      @empty_http_header_counter += 1
      {
        :headers => {
          "X-Empty-Http-Header-Curl-Workaround#{@empty_http_header_counter}" => "ignore\r\n#{header}:",
        },
      }
    end

    def run_shell(command)
      output = `#{command} 2>&1`
      status = $CHILD_STATUS.to_i
      [output, status]
    end
  end
end
