# Set the servers for this stage.
role :app, "api.vagrant"
role :web, "api.vagrant"

# Set the base path for deployment.
set :deploy_to_base, "/srv/sites"

set(:release_name) { application }
set(:releases_path) { File.join("/vagrant/workspace") }
set(:releases) { [application] }

# Set the accessible web domain for this site.
set :base_domain, "api.vagrant"

# Only maintain a single release and checkout for our local development. This
# means there's no ability to rollback releases.
set :deploy_via, :no_op

# Set the Rails environment.
set :rails_env, "development"

# Set gem bundler options for the development environment.
set :bundle_without, [:test]
set :bundle_flags, "--quiet"

set :group_writable, false
set :disable_internal_symlinks, true
