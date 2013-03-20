require "capistrano_nrel_ext/recipes/development_deploy"
require "capistrano_nrel_ext/recipes/sandboxes"

# Set the servers for this stage.
role :app, "devdev.nrel.gov"
role :web, "devdev.nrel.gov"

# Define the primary db server as our app server so database migrations can run
# from the code checkout there.
role :db, "devdev.nrel.gov", :primary => true

# On our real database server, don't actually perform a code deployment.
role :db, "devdev-db.nrel.gov", :no_release => true

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/sites"
set :releases_path_base, "/srv/developer"

# Set the accessible web domain for this site.
set :base_domain, "dev.api.data.gov"

# Set the Rails environment.
set :rails_env, "development"
