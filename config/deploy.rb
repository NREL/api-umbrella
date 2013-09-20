# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/gem_bundler"
require "capistrano_nrel_ext/recipes/npm"
require "capistrano_nrel_ext/recipes/nginx"
require "capistrano_nrel_ext/recipes/supervisor"

# Set the application being deployed.
set :application, "api-umbrella-router"

set :scm, "git"
set :repository, "https://github.com/NREL/api-umbrella-router.git"
set :git_enable_submodules, true
set :branch, "master"

ssh_options[:forward_agent] = true

set :npm_apps, ["gatekeeper"]

set :web_server_user, "www-data-local"

set :shared_children_files, %w(config/gatekeeper/runtime.yml config/gatekeeper/runtime.json config/gatekeeper/nginx.conf)
set :writable_children_dirs, %w(config/gatekeeper)

after "deploy:setup", "deploy:app:setup_dirs"
after "deploy:finalize_permissions", "deploy:app:finalize_permissions"

namespace :deploy do
  namespace :app do
    task :setup_dirs, :except => { :no_release => true } do
      run "#{try_sudo} mkdir -p #{File.join(shared_path, "log/gatekeeper")}"
    end

    task :finalize_permissions, :except => { :no_release => true } do
      run "setfacl -R -m 'u:api-umbrella-gatekeeper:rwx' #{File.join(shared_path, "config/gatekeeper")}"
    end
  end
end
