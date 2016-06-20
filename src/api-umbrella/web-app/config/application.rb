require File.expand_path('../boot', __FILE__)

# Pick the frameworks you want:
# require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "active_resource/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(:assets => %w(development test)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module ApiUmbrella
  class Application < Rails::Application
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

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/app/workers)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    # config.active_record.observers = :cacher, :garbage_collector, :forum_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.enforce_available_locales = true

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

    # Enable escaping HTML in JSON.
    config.active_support.escape_html_entities_in_json = true

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    # config.active_record.schema_format = :sql

    # Enforce whitelist mode for mass assignment.
    # This will create an empty whitelist of attributes available for mass-assignment for all models
    # in your app. As such, your models will need to explicitly whitelist or blacklist accessible
    # parameters by using an attr_accessible or attr_protected declaration.
    # config.active_record.whitelist_attributes = true

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

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.0'

    # Include the config/locales directory on the asset path so that the locale
    # YAML files can be setup as "depend_on" dependencies inside assets (for
    # use with JsLocaleHelper).
    config.assets.paths += %W(#{config.root}/config/locales)

    # Choose the compressors to use
    config.assets.js_compressor  = :uglifier

    # Rely on Sass's built-in compressor for CSS minifying.
    # config.assets.css_compressor = :yui

    # Move default assets directory so this project can co-exist with the
    # static-site projectt that delivers most of the web content.
    config.assets.prefix = "/web-assets"

    # Reset the default precompile list list to exclude our vendored submodule
    # stuff. This should go away in Rails 4, where vendor/assets is
    # automatically excluded.
    # Based on the original here:
    # https://github.com/rails/rails/blob/v3.2.17/railties/lib/rails/application/configuration.rb#L48-L49
    config.assets.precompile = [
      proc do |path|
        !File.extname(path).in?(['.js', '.css']) && path !~ /^vendor/
      end,
      /(?:\/|\\|\A)application\.(css|js)$/,
    ]

    # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
    config.assets.precompile += %w(
      admin.css
      admin.js
      admin/stats.js
      ie_lt_9.js
    )

    # Detect and precompile all the locale assets.
    Dir.glob("#{config.root}/app/assets/javascripts/admin/locales/*.js.erb").each do |path|
      config.assets.precompile << path.gsub(%r{^.*/app/assets/javascripts/}, "").gsub(/\.erb$/, "")
    end

    # Setup ember and handlebars, but only when it's being required (so
    # development and test, but only production when running assets:precompile
    # with RAILS_GROUPS=assets).
    if(config.respond_to?(:ember))
      config.ember.variant = :development
      config.handlebars.templates_root = ["admin/templates", "templates"]
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
