require "capistrano_nrel_ext/recipes/sandboxes"

# Set the servers for this stage.
role :app, "cttsdev-svc.nrel.gov"
role :web, "cttsdev-svc.nrel.gov"

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/cttsdev-svc"

# Set the accessible web domain for this site.
set :base_domain, "cttsdev-svc.nrel.gov"

# Reduce the number of copies kept since this is the development environment.
set :keep_releases, 5

# Set the Rails environment.
set :rails_env, "development"
