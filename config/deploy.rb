# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/npm"
require "capistrano_nrel_ext/recipes/haproxy"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/supervisor"

# Set the application being deployed.
set :application, "api-umbrella-router"

set :scm, "git"
set :repository, "https://github.com/NREL/api-umbrella-router.git"
set :branch, "master"

ssh_options[:forward_agent] = true

set :npm_apps, ["."]
