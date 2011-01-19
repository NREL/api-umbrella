require "rubygems"

# Setup gem bundler for dependencies.
ENV["BUNDLE_GEMFILE"] = File.expand_path("../Gemfile", __FILE__)
require "bundler"
Bundler.setup

# Define a constant so we always know the AuthProxy's base location.
AUTH_PROXY_ROOT = File.expand_path("..", __FILE__)

# Add load paths.
$LOAD_PATH.unshift(File.join(AUTH_PROXY_ROOT, "lib"))
$LOAD_PATH.unshift(File.join(AUTH_PROXY_ROOT, "models"))

# Define the default Rails environment for when we need to interact with Rails
# models.
ENV["RAILS_ENV"] ||= "development"

# Load the base configuration for MongoMapper, so those models can connect to
# MongoDB.
require "mongoid"
require "erb"
mongoid_settings_file = ::File.join(AUTH_PROXY_ROOT, "config", "mongoid.yml")
mongoid_settings = YAML::load(ERB.new(IO.read(mongoid_settings_file)).result)
puts "MONGOID SETTINGS: #{mongoid_settings.inspect}"
mongoid_settings[ENV["RAILS_ENV"]] ||= {}
puts "MONGOID SETTINGS: #{mongoid_settings.inspect}"
Mongoid.configure do |config|
puts "MONGOID SETTINGS: #{mongoid_settings[ENV["RAILS_ENV"]].inspect}"
  config.from_hash(mongoid_settings[ENV["RAILS_ENV"]])
end

# Define a ProxyMachine proxy server with our logic stored in the
# {#AuthProxy::Proxy} class.
require "auth_proxy/proxy"
proxy(&AuthProxy::Proxy.proxymachine_router)
