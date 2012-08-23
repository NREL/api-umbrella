# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/asset_pipeline"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/rails"
require "capistrano_nrel_ext/recipes/redhat"

# Set the application being deployed.
set :application, "developer"

set :scm, "git"
set(:repository) { "git@github.com:NREL/#{application}.git" }
set(:branch) { branch_name || "HEAD" }
set :deploy_via, :copy
set :copy_cache, true
set :copy_exclude, ".git/*"

if(File.exists?("/usr/bin/gnutar"))
  set :copy_local_tar, "gnutar"
end

ssh_options[:forward_agent] = true

# Define the rails-based applications.
set :rails_app_paths,  {
  "." => "/",
}
