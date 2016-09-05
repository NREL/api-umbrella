require File.expand_path('../boot', __FILE__)

require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "sprockets/railtie"

# Log to stdout when running as a server process (like all the other perpd
# processes API Umbrella manages).
require "rails_stdout_logging" if(ENV["RAILS_LOG_TO_STDOUT"].present?)

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module ApiUmbrella
  class Application < Rails::Application
    config.autoload_paths += ["#{config.root}/lib"]
    config.eager_load_paths += ["#{config.root}/lib"]

    config.before_configuration do
      require "symbolize_helper"

      config_files = []
      config_file = ENV["API_UMBRELLA_RUNTIME_CONFIG"]
      if(config_file.present?)
        config_files << config_file
      end

      # In non-test environments, load the system-wide runtime_config.yml file
      # if it exists and the API_UMBRELLA_RUNTIME_CONFIG environment variable
      # isn't set (this allows for more easily running "rails console" on
      # without having to specify this environment variable). We don't set this
      # in the test environment, since we don't want development environment
      # config to be used in test (assuming you're testing from the same
      # machine you're developing on).
      if(config_files.blank? && Rails.env != "test")
        default_runtime_config_file = "/opt/api-umbrella/var/run/runtime_config.yml"
        if(File.exist?(default_runtime_config_file) && File.readable?(default_runtime_config_file))
          config_files << default_runtime_config_file
        end
      end

      # If no config environment variable is set and we're not using the
      # default runtime config file, then fall back to the default.yml file at
      # the top-level of the api-umbrella repo.
      if(config_files.blank?)
        config_files << File.expand_path("../../../../../config/default.yml", __FILE__)

        if(Rails.env == "test")
          if(ENV["API_UMBRELLA_CONFIG"].present?)
            config_files += ENV["API_UMBRELLA_CONFIG"].split(":")
          else
            config_files << File.expand_path("../../../../../test/config/test.yml", __FILE__)
          end
        end
      end

      # Load the YAML config in.
      config = {}
      config_files.each do |file|
        data = SymbolizeHelper.symbolize_recursive(YAML.load_file(file))
        config.deep_merge!(data)
      end

      if(Rails.env == "test")
        # When running as part of the integration test suite, where we run all
        # the API Umbrella processes separately, ensure we connect to those
        # ports.
        if(ENV["INTEGRATION_TEST_SUITE"])
          config[:mongodb][:url] = "mongodb://127.0.0.1:13001/api_umbrella_test"

          # Don't override the Elasticsearch v2 connection tests.
          if(config[:elasticsearch][:hosts] != ["http://127.0.0.1:9200"])
            config[:elasticsearch][:hosts] = ["http://127.0.0.1:13002"]
          end

        # If not running as part of the integration test suite, then we assume
        # a developer is just running the rails tests a standalone command. In
        # that case, we'll connect to the default API Umbrella ports for
        # databases that we assume are running in the development environment.
        # The only difference is MongoDB, where we want to make sure we connect
        # to a separate test database so tests don't interfere with
        # development.
        elsif(!ENV["FULL_STACK_TEST"])
          config[:mongodb][:url] = "mongodb://127.0.0.1:14001/api_umbrella_test"

          # Don't override the Elasticsearch v2 connection tests.
          if(config[:elasticsearch][:hosts] != ["http://127.0.0.1:9200"])
            config[:elasticsearch][:hosts] = ["http://127.0.0.1:14002"]
          end
        end
      end

      # Set the default host used for web application links (for mailers,
      # contact URLs, etc).
      #
      # By default, pick this up from the `hosts` array where `default` has
      # been set to true (this gets put on `_default_hostname` for easier
      # access). But still allow the web host to be explicitly set via
      # `web.default_host`.
      if(config[:web][:default_host].blank?)
        config[:web][:default_host] = config[:_default_hostname]

        # Fallback to something that will at least generate valid URLs if
        # there's no default, or the default is "*" (since in this context, a
        # wildcard doesn't make sense for generating URLs).
        if(config[:web][:default_host].blank? || config[:web][:default_host] == "*")
          config[:web][:default_host] = "localhost"
        end
      end

      # rubocop:disable Style/ConstantName
      ::ApiUmbrellaConfig = config
      # rubocop:enable Style/ConstantName

      require "js_locale_helper"
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    if(ENV["RAILS_TMP_PATH"].present?)
      paths["tmp"] = ENV["RAILS_TMP_PATH"]
      tmp_assets_cache_path = File.join(ENV["RAILS_TMP_PATH"], "cache/assets")
      FileUtils.mkdir_p(tmp_assets_cache_path)
      config.assets.cache_store = [:file_store, tmp_assets_cache_path]
      config.sass.cache_location = File.join(ENV["RAILS_TMP_PATH"], "cache/sass")
    end

    if(ENV["RAILS_PUBLIC_PATH"].present?)
      paths["public"] = ENV["RAILS_PUBLIC_PATH"]
    end

    # Use a mongo-based cache store (this ensures the cache can be shared
    # amongst multiple servers).
    config.cache_store = :mongoid_store

    config.action_mailer.raise_delivery_errors = true
    config.action_mailer.default_url_options = {
      :host => ApiUmbrellaConfig[:web][:default_host],
    }

    if(ApiUmbrellaConfig[:web] && ApiUmbrellaConfig[:web][:mailer] && ApiUmbrellaConfig[:web][:mailer][:smtp_settings])
      config.action_mailer.smtp_settings = ApiUmbrellaConfig[:web][:mailer][:smtp_settings]
    end
  end
end
