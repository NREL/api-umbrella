ApiUmbrella::Application.routes.draw do

  get "/doc/api-key" => "pages#api_key", :as => :doc_api_key
  get "/doc/errors" => "pages#errors"
  get "/doc/rate-limits" => "pages#rate_limits", :as => :doc_rate_limits

  get "/doc" => "api_doc_collections#index"
  get "/doc/api/:path" => "api_doc_services#show", :as => :api_doc_service, :constraints => {:path => /.*/}
  get "/doc/:slug" => "api_doc_collections#show", :as => :api_doc_collection

  get "/community" => "pages#community"

  resource :account, :only => [:create] do
    get "terms", :on => :collection
  end

  get "/signup" => "accounts#new"

  get "/contact" => "contacts#new"
  post "/contact" => "contacts#create"

  root :to => "pages#home"

  namespace :api do
    resources :api_users, :path => "api-users", :only => [:show, :create] do
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
  end

  devise_for :admins, :controllers => { :omniauth_callbacks => "admin/admins/omniauth_callbacks" }

  devise_scope :admin do
    get "/admin/login" => "admin/sessions#new", :as => :new_admin_session
    get "/admin/logout" => "admin/sessions#destroy", :as => :destroy_admin_session
  end

  match "/admin" => "admin/base#empty"

  namespace :admin do
    resources :api_users

    resources :stats, :only => [:index] do
      collection do
        get "search"
        get "logs"
        get "users"
        get "map"
      end
    end

    resources :apis

    namespace :config do
      get "publish", :action => "show"
      post "publish", :action => "create"
    end

    resources :admins do
      get "page/:page", :action => :index, :on => :collection
    end

    resources :api_doc_services do
      get "page/:page", :action => :index, :on => :collection
    end

    resources :api_doc_collections do
      get "page/:page", :action => :index, :on => :collection
    end

    resources :api_users do
      get "page/:page", :action => :index, :on => :collection
    end
  end
end
