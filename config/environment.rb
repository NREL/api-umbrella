require "rubygems"

# Setup gem bundler for dependencies.
ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
require "bundler"
Bundler.setup

# Setup the LOGGER constant that ProxyMachine uses if we're not inside
# proxymachine (eg, we're running tests).
if(!defined?(LOGGER))
  require "logger"
  LOGGER = Logger.new(STDOUT)
end

# Define a constant so we always know the AuthProxy's base location.
AUTH_PROXY_ROOT = File.expand_path("../../", __FILE__)

# Add load paths.
$LOAD_PATH.unshift(File.join(AUTH_PROXY_ROOT, "lib"))
$LOAD_PATH.unshift(File.join(AUTH_PROXY_ROOT, "models"))

# Define the default Rack environment for when we need to interact with models.
ENV["RACK_ENV"] ||= "development"

# Load Mongoid's configuration for this specific environment.
require "mongoid"
Mongoid.load!(::File.join(AUTH_PROXY_ROOT, "config", "mongoid.yml"))
