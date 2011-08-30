# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/jammit"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/rails"
require "capistrano_nrel_ext/recipes/redhat"

# Set the application being deployed.
set :application, "developer"

# FIXME: Checkout our rhel6 branch for now. Remove to checkout trunk after
# rhel6 branch goes live.
set :repository, "https://cttssvn.nrel.gov/svn/developer_apps/branches/rhel6/developer"

# Define the rails-based applications.
set :rails_applications, [
  ".",
]
