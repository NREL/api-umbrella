# Set the servers for this stage.
role :app, "devdev-new.nrel.gov"
role :web, "devdev-new.nrel.gov"

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/devdev"

# Set the accessible web domain for this site.
set :base_domain, "devdev-new.nrel.gov"

# Reduce the number of copies kept since this is the development environment.
set :keep_releases, 5

# Set the Rails environment.
set :rails_env, "development"
