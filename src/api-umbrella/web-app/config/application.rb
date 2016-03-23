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
      default_config = "/opt/api-umbrella/var/run/runtime_config.yml"
      if(ENV["API_UMBRELLA_RUNTIME_CONFIG"].blank? && File.exist?(default_config) && File.readable?(default_config))
        ENV["API_UMBRELLA_RUNTIME_CONFIG"] = default_config
      end

      if(ENV["API_UMBRELLA_RUNTIME_CONFIG"])
        ApiUmbrellaConfig.add_source!(ENV["API_UMBRELLA_RUNTIME_CONFIG"])
        ApiUmbrellaConfig.reload!
      end

      # Provide default config values for arrays when a real API Umbrella
      # config file isn't passed in (via the API_UMBRELLA_RUNTIME_CONFIG
      # environment variable).
      #
      # Most defaults should be defined in config/settings.yml, but array
      # values don't overwrite well with RailsConfig, so we'll define the array
      # default values here. Revisit if RailsConfig addresses this so arrays
      # can overwrite, rather than append:
      # https://github.com/railsconfig/rails_config/issues/12
      if(ApiUmbrellaConfig[:elasticsearch][:hosts].blank?)
        ApiUmbrellaConfig[:elasticsearch][:hosts] = ["http://127.0.0.1:9200"]
      end

      if(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:enabled].blank?)
        ApiUmbrellaConfig[:web][:admin][:auth_strategies][:enabled] = [
          "github",
          "persona",
        ]
      end

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
      :host => ApiUmbrellaConfig[:default_host],
    }

    if(ApiUmbrellaConfig[:web] && ApiUmbrellaConfig[:web][:mailer] && ApiUmbrellaConfig[:web][:mailer][:smtp_settings])
      config.action_mailer.smtp_settings = ApiUmbrellaConfig[:web][:mailer][:smtp_settings]
    end
  end
end
