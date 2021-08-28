require File.expand_path("boot", __dir__)

require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

if(Rails.env.development? || ENV["RAILS_ASSETS_PRECOMPILE"])
  require "bootstrap"
  require "font-awesome-rails"
end

module ApiUmbrella
  class Application < Rails::Application
    config.autoload_paths += ["#{config.root}/lib"]
    config.eager_load_paths += ["#{config.root}/lib"]

    config.before_configuration do
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
      if(config_files.blank? && !Rails.env.test? && !ENV["RAILS_ASSETS_PRECOMPILE"])
        default_runtime_config_file = "/opt/api-umbrella/var/run/runtime_config.yml"
        if(File.exist?(default_runtime_config_file) && File.readable?(default_runtime_config_file))
          config_files << default_runtime_config_file
        end
      end

      # If no config environment variable is set and we're not using the
      # default runtime config file, then fall back to the default.yml file at
      # the top-level of the api-umbrella repo.
      if(config_files.blank? && !ENV["RAILS_ASSETS_PRECOMPILE"])
        config_files << File.expand_path("../../../../config/default.yml", __dir__)

        if(Rails.env.test?)
          if(ENV["API_UMBRELLA_CONFIG"].present?)
            config_files += ENV["API_UMBRELLA_CONFIG"].split(":")
          else
            config_files << File.expand_path("../../../../test/config/test.yml", __dir__)
          end
        end
      end

      # Load the YAML config in.
      config = {}
      config_files.each do |file|
        data = YAML.load_file(file).deep_symbolize_keys
        config.deep_merge!(data)
      end

      # rubocop:disable Naming/ConstantName
      ::ApiUmbrellaConfig = config
      # rubocop:enable Naming/ConstantName

      unless ENV["RAILS_ASSETS_PRECOMPILE"]
        require "js_locale_helper"
      end
    end

    # Instead of loading from a mongoid.yml file, load the Mongoid config in
    # code, where it's easier to merge settings from our API Umbrella
    # configuration.
    unless ENV["RAILS_ASSETS_PRECOMPILE"]
      initializer "mongoid-config", :after => "mongoid.load-config" do
        config = {
          :clients => {
            :default => {
              :uri => ApiUmbrellaConfig[:mongodb][:url],
              :options => {
                :read => {
                  :mode => ApiUmbrellaConfig[:mongodb][:read_preference].to_s.underscore.to_sym,
                },
                :truncate_logs => false,
              },
            },
          },
        }

        Mongoid::Clients.disconnect
        Mongoid::Clients.clear
        Mongoid.load_configuration(config)
      end
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

    # Allow the Rails tmp path to be configured to be outside of the source
    # directory.
    if(ENV["RAILS_TMP_PATH"].present?)
      config.paths["tmp"] = ENV["RAILS_TMP_PATH"]
      config.assets.configure do |env|
        env.cache = Sprockets::Cache::FileStore.new(
          File.join(ENV["RAILS_TMP_PATH"], "cache/assets"),
          config.assets.cache_limit,
          env.logger,
        )
      end
    end

    # Allow the Rails public path to be configured to be outside of the source
    # directory. This allows API Umbrella builds (resulting in precompiled
    # assets) to happen in a build-specific directory.
    #
    # However, in development, ignore this, since we don't want precompiled
    # assets from a build to be picked up and used.
    if(ENV["RAILS_PUBLIC_PATH"].present? && !Rails.env.development?)
      config.paths["public"] = ENV["RAILS_PUBLIC_PATH"]
    end

    # Use a mongo-based cache store (this ensures the cache can be shared
    # amongst multiple servers).
    config.cache_store = :mongoid_store

    # Use delayed job for background jobs.
    config.active_job.queue_adapter = :delayed_job

    config.action_mailer.raise_delivery_errors = true

    if(ApiUmbrellaConfig[:web] && ApiUmbrellaConfig[:web][:default_host])
      config.action_mailer.default_url_options = {
        :host => ApiUmbrellaConfig[:web][:default_host],
      }
    end

    if(ApiUmbrellaConfig[:web] && ApiUmbrellaConfig[:web][:mailer] && ApiUmbrellaConfig[:web][:mailer][:smtp_settings])
      config.action_mailer.smtp_settings = ApiUmbrellaConfig[:web][:mailer][:smtp_settings]
    end

    config.middleware.use HttpAcceptLanguage::Middleware
  end
end
