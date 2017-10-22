require "English"
require "ipaddr"
require "support/api_umbrella_test_helpers/common_asserts"

module ApiUmbrellaTestHelpers
  module Setup
    extend ActiveSupport::Concern

    include ApiUmbrellaTestHelpers::CommonAsserts
    include ApiUmbrellaTestHelpers::AdminAuth

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
    mattr_accessor(:setup_lock) { Monitor.new }
    mattr_accessor(:config_lock) { Monitor.new }
    mattr_accessor(:config_set_lock) { Monitor.new }
    mattr_accessor(:config_publish_lock) { Monitor.new }

    included do
      mattr_accessor :class_setup_complete
      mattr_accessor(:class_setup_lock) { Monitor.new }
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
      self.setup_lock.synchronize do
        unless self.start_complete
          # Start the API Umbrella process to test against.
          ApiUmbrellaTestHelpers::Process.start
          self.start_complete = true

          ActiveRecord::Base.establish_connection({
            :adapter => "postgresql",
            :host => $config["postgresql"]["host"],
            :port => $config["postgresql"]["port"],
            :database => $config["postgresql"]["database"],
            :username => "api-umbrella",
            :pool => 50,
            :variables => {
              "timezone" => "UTC",
              "application_name" => "test_app_name",
              "audit.user_id" => "00000000-1111-2222-3333-444444444444",
              "audit.user_name" => "test_example_admin_username",
            },
          })
        end
      end

      super
    end

    private

    def setup_server
      self.setup_lock.synchronize do
        unless self.setup_complete
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

        unless self.setup_api_user_complete
          ApiUser.where("registration_source != 'seed'").delete_all
          user = FactoryGirl.create(:api_user, {
            :registration_source => "seed",
            :settings => FactoryGirl.build(:api_user_settings, {
              :rate_limit_mode => "unlimited",
            }),
          })

          @@api_user = user
          @@api_key = user.api_key
          assert(@@api_key)
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
              "X-Api-Key" => @@api_key,
            }.freeze,
          }.freeze
          @@keyless_http_options = @@http_options.except(:headers).freeze

          self.setup_api_user_complete = true
        end

        unless self.setup_config_version_complete
          PublishedConfig.delete_all
          api_backend = ApiBackend.create!({
            :name => "default-test-api-backend",
            :backend_protocol => "http",
            :balance_algorithm => "least_conn",
            :frontend_host => "127.0.0.1",
            :backend_host => "127.0.0.1",
            :servers => [
              ApiBackendServer.new(:host => "127.0.0.1", :port => 9444),
            ],
            :url_matches => [
              ApiBackendUrlMatch.new(:frontend_prefix => "/api/", :backend_prefix => "/"),
            ],
          })
          publish_api_backends([api_backend.id])
          api_backend.delete
          self.setup_config_version_complete = true
        end
      end
    end

    # If tests need to delete all the PublishedConfig records from the database,
    # then they need to call this method after finishing so the default
    # PublishedConfig record will be re-created for other tests that depend on
    # it.
    def default_config_version_needed
      ApiUmbrellaTestHelpers::Setup.setup_lock.synchronize do
        ApiUmbrellaTestHelpers::Setup.setup_config_version_complete = false
      end
    end

    # If tests need to delete all the ApiUser records from the database, then
    # they need to call this method after finishing so the default ApiUser
    # record will be re-created for other tests that depend on it.
    def default_api_user_needed
      ApiUmbrellaTestHelpers::Setup.setup_lock.synchronize do
        ApiUmbrellaTestHelpers::Setup.setup_api_user_complete = false
      end
    end

    def once_per_class_setup
      unless self.class_setup_complete
        self.class_setup_lock.synchronize do
          unless self.class_setup_complete
            yield
            self.class_setup_complete = true
          end
        end
      end
    end

    def prepend_api_backends(api_attributes)
      @prepend_api_backends_counter ||= 0
      api_ids = api_attributes.map! do |attributes|
        attributes.deep_symbolize_keys!

        @prepend_api_backends_counter += 1
        attributes[:name] ||= "#{unique_test_id}-#{@prepend_api_backends_counter}"
        attributes[:backend_protocol] ||= "http"
        attributes[:balance_algorithm] ||= "least_conn"

        response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", @@http_options.deep_merge(admin_token).deep_merge({
          :headers => { "Content-Type" => "application/json" },
          :body => MultiJson.dump(:api => attributes),
        }))
        assert_response_code(201, response)
        data = MultiJson.load(response.body)

        id = data["api"]["id"]
        assert(id)

        id
      end

      publish_api_backends(api_ids)

      yield if(block_given?)
    ensure
      if(block_given?)
        unpublish_api_backends(api_ids)
      end
    end

    def prepend_website_backends(website_attributes)
      website_ids = website_attributes.map do |attributes|
        attributes.deep_stringify_keys!
        WebsiteBackend.create!(attributes).id
      end

      publish_website_backends(website_ids)

      yield if(block_given?)
    ensure
      if(block_given?)
        unpublish_website_backends(website_ids)
      end
    end

    def publish_api_backends(record_ids)
      publish_backends("apis", record_ids)
    end

    def publish_website_backends(record_ids)
      publish_backends("website_backends", record_ids)
    end

    # Publish backend changes for the given record IDs.
    #
    # Publishing is performed by hitting the internal publish API endpoint. We
    # do this via the API, rather than directly manipulating the
    # PublishedConfig database table, since the resulting published config is
    # dependent on how backend records get serialized into JSON during the
    # publishing process. Since the Lua models might do this differently, use
    # the real API to ensure we're testing the real publishing process, and the
    # real resulting JSON.
    def publish_backends(type, record_ids)
      self.config_publish_lock.synchronize do
        config = { type => {} }
        record_ids.each do |record_id|
          config[type][record_id] = { :publish => "1" }
        end

        response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/config/publish.json", @@http_options.deep_merge(admin_token).deep_merge({
          :headers => { "Content-Type" => "application/json" },
          :body => MultiJson.dump(:config => config),
        }))

        assert_response_code(201, response)
        PublishedConfig.active.wait_until_live
      end
    end

    def unpublish_api_backends(record_ids)
      self.config_publish_lock.synchronize do
        ApiBackend.delete(record_ids)
        publish_backends("apis", record_ids)
      end
    end

    def unpublish_website_backends(record_ids)
      self.config_publish_lock.synchronize do
        WebsiteBackend.delete(record_ids)
        publish_backends("website_backends", record_ids)
      end
    end

    def override_config(config, reload_flag)
      self.config_lock.synchronize do
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
      self.config_set_lock.synchronize do
        if(self.class.test_order == :parallel)
          raise "`override_config_set` cannot be called with `parallelize_me!` in the same class. Since overriding config affects the global state, it cannot be used with parallel tests."
        end

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
      @unique_test_class_id ||= self.class.name.gsub(/[^\w]+/, "-")
    end

    def unique_test_id
      @unique_test_id ||= self.location.gsub(/[^\w]+/, "-")
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
          # First set the header to null to prevent Typheous from adding some
          # default headers back in (like Content-Type).
          header => nil,

          # Next, add a fake header, and in the content of the header add line
          # breaks and the real header without a value.
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
