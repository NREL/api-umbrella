# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/asset_pipeline"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/rails"
require "capistrano_nrel_ext/recipes/redhat"

# Set the application being deployed.
set :application, "api-umbrella-web"

set :scm, "git"
set :repository, "https://github.com/NREL/api-umbrella-web.git"
set :git_enable_submodules, true
set :branch, "gsa"

ssh_options[:forward_agent] = true

# Define the rails-based applications.
set :rails_app_paths,  {
  "." => "/",
}
