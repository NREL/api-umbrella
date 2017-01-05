require "api_umbrella/elasticsearch_proxy"

Rails.application.routes.draw do
  # Add a simple health-check endpoint to see if this app is up.
  get "/_web-app-health", :to => proc { [200, {}, ["OK"]] }

  # Mount the API at both /api/ and /api-umbrella/ for backwards compatibility.
  %w(api api-umbrella).each do |path|
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

  # Add an endpoint for admin-ui to hit to return the detected language based
  # on the Accept-Language HTTP header.
  #
  # At some point we may want to revisit this to be purely client-side, but
  # this currently seems like the easiest approach to ensure that the parsed
  # client-side language is consistent with the server-side language, and this
  # can be tested with Capybara (purely client-side approaches based on
  # "navigator.languages" can't really seem to be changed in
  # Capybara+poltergeist).
  get "/admin/i18n_detection.js", :to => proc { |env|
    locale = env["http_accept_language.parser"].compatible_language_from(I18n.available_locales) || I18n.default_locale

    [
      200,
      {
        "Content-Type" => "application/javascript",
        "Cache-Control" => "max-age=0, private, must-revalidate",
      },
      [
        "I18n = {};",
        "I18n.defaultLocale = #{I18n.default_locale.to_json};",
        "I18n.locale = #{locale.to_json};",
        "I18n.fallbacks = true;",
      ],
    ]
  }

  # Add a dummy /admin/ route. This URL actually gets routed to the Ember.js
  # app, not the Rails app, but we create this dummy route so we have the Rails
  # "admin_path" and "admin_url" URL helpers available (for redirecting to the
  # root of the admin).
  get "/admin/", :to => proc { [200, {}, ["OK"]] }
end
