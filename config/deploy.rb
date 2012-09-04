# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/haproxy"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/supervisor"

# Set the application being deployed.
set :application, "developer_router"
