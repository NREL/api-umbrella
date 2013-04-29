require "capistrano_nrel_ext/recipes/development_deploy"

# Set the servers for this stage.
role :app, "devdev.nrel.gov"
role :web, "devdev.nrel.gov"

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/sites"
set :releases_path_base, "/srv/developer"

# Set the accessible web domain for this site.
set :base_domain, "devdev.nrel.gov"

# Set the Rails environment.
set :rails_env, "development"
