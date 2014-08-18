role :app, ["#{ENV["USER"]}@localhost"]
role :web, ["#{ENV["USER"]}@localhost"]
role :db, []

fetch(:default_env).merge!({
 "RAILS_SECRET_TOKEN"  => "TEMP",
 "DEVISE_SECRET_KEY"  => "TEMP",
})
