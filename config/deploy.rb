# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/haproxy"
require "capistrano_nrel_ext/recipes/supervisor"

# Set the application being deployed.
set :application, "developer_router"

# FIXME: Checkout our rhel6 branch for now. Remove to checkout trunk after
# rhel6 branch goes live.
set :repository, "https://cttssvn.nrel.gov/svn/developer_router/branches/rhel6"

# Bundle gems for the auth_proxy app.
set :gem_bundler_apps, [
  "auth_proxy",
]
