unless ENV["RAILS_ASSETS_PRECOMPILE"]
  require "api_umbrella/elasticsearch_proxy"
end

Rails.application.routes.draw do
  break if ENV["RAILS_ASSETS_PRECOMPILE"]

  # Add a simple health-check endpoint to see if this app is up.
  get "/_web-app-health", :to => proc { [200, {}, ["OK"]] }

  # Mount the API at both /api/ and /api-umbrella/ for backwards compatibility.
  ["api", "api-umbrella"].each do |path|
    namespace(:api, :path => path) do
      resources :api_users, :path => "api-users" do
        member do
          get "validate"
        end
      end

      resources :health_checks, :path => "health-checks", :only => [] do
        collection do
          get :ip
          get :logging
        end
      end

      # /v0 is for unstable APIs we may be experimenting with internally.
      namespace :v0 do
        resources :analytics do
          collection do
            get "summary"
          end
        end
      end

      namespace :v1 do
        resources :admin_groups
        resources :admin_permissions, :only => [:index]
        resources :user_roles, :only => [:index]
        resources :admins
        resources :api_scopes
        resources :apis do
          member do
            put "move_after"
          end
        end
        resources :users, :except => [:destroy]
        resources :website_backends
        resource :contact, :only => [:create]

        resources :analytics do
          collection do
            get "drilldown"
          end
        end

        namespace :config do
          get :pending_changes
          post :publish
        end
      end
    end
  end

  devise_for :admins,
    :skip => [
      :sessions,
      :registrations,
    ],
    :path_names => {
      :sign_in => "login",
      :sign_out => "logout",
    },
    :controllers => {
      :omniauth_callbacks => "admin/admins/omniauth_callbacks",
    }
  devise_scope :admin do
    get "/admin/login" => "admin/sessions#new", :as => :new_admin_session
    post "/admin/login" => "admin/sessions#create", :as => :admin_session
    delete "/admin/logout" => "admin/sessions#destroy", :as => :destroy_admin_session
    get "/admin/auth" => "admin/sessions#auth"

    resource :registration,
      :only => [:new, :create],
      :path => "admins",
      :path_names => { :new => "signup" },
      :controller => "admin/registrations",
      :as => :admin_registration
  end

  namespace :admin do
    resources :stats, :only => [:index] do
      collection do
        get "search"
        get "logs"
        post "logs"
        get "users"
        get "map"
      end
    end

    resources :api_users do
      get "page/:page", :action => :index, :on => :collection
    end
  end

  authenticate :admin do
    mount ApiUmbrella::ElasticsearchProxy.new => ApiUmbrella::ElasticsearchProxy::PREFIX
  end

  # Add an endpoint for admin-ui to hit to return server-side data to share
  # with the client side. This consists of shared locale data, locale
  # detection, and some shared validations.
  get "/admin/server_side_loader.js", :to => proc { |env|
    # Detect the user's language based on their Accept-Language HTTP header.
    locale = (env["http_accept_language.parser"].language_region_compatible_from(I18n.available_locales) || I18n.default_locale).to_s

    # Cache the generated javascript on a per-locale basis (since the response
    # will differ depending on the user's locale).
    cache_key = :"server_side_loader_cache_#{locale}"

    script = nil
    unless(Rails.env.development?)
      script = Thread.current[cache_key]
    end

    unless(script)
      # Fetch the locale data just for the user's language, as well as the
      # default language (if it's different) for fallback support.
      locale_data = {}
      locale_data[locale] = I18n::JS.translations[locale.to_sym]
      locale_data[I18n.default_locale.to_s] ||= I18n::JS.translations[I18n.default_locale.to_sym]
      JsLocaleHelper.markdown!(locale_data)

      script = <<~EOS
        I18n = window.I18n || {};
        I18n.defaultLocale = #{I18n.default_locale.to_json};
        I18n.locale = #{locale.to_json};
        I18n.translations = #{locale_data.to_json};
        I18n.fallbacks = true;
        var CommonValidations = {
          host_format: new RegExp(#{CommonValidations.to_js(CommonValidations::HOST_FORMAT).to_json}),
          host_format_with_wildcard: new RegExp(#{CommonValidations.to_js(CommonValidations::HOST_FORMAT_WITH_WILDCARD).to_json}),
          url_prefix_format: new RegExp(#{CommonValidations.to_js(CommonValidations::URL_PREFIX_FORMAT).to_json})
        };
      EOS

      Thread.current[cache_key] = script
    end

    [
      200,
      {
        "Content-Type" => "application/javascript",
        "Cache-Control" => "no-cache, max-age=0, must-revalidate, no-store",
        "Pragma" => "no-cache",
      },
      [
        script,
      ],
    ]
  }

  # Add a dummy /admin/ route. This URL actually gets routed to the Ember.js
  # app, not the Rails app, but we create this dummy route so we have the Rails
  # "admin_path" and "admin_url" URL helpers available (for redirecting to the
  # root of the admin).
  get "/admin/", :to => proc { [200, {}, ["OK"]] }
end
