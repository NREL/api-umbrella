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
require "mongo_mapper"
require "erb"
config_file = ::File.join(AUTH_PROXY_ROOT, "config", "mongodb.yml")
config = YAML::load(ERB.new(IO.read(config_file)).result)
config[ENV["RAILS_ENV"]] ||= {}
MongoMapper.setup(config, ENV["RAILS_ENV"], :logger => LOGGER)

# Define a ProxyMachine proxy server with our logic stored in the
# {#AuthProxy::Proxy} class.
require "auth_proxy/proxy"
proxy(&AuthProxy::Proxy.proxymachine_router)
