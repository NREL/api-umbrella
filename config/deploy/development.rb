require "capistrano_nrel_ext/recipes/sandboxes"

# Set the servers for this stage.
role :app, "devdev-new.nrel.gov"
role :web, "devdev-new.nrel.gov"

# Define the primary db server as our app server so database migrations can run
# from the code checkout there.
role :db, "devdev-new.nrel.gov", :primary => true

# On our real database server, don't actually perform a code deployment.
role :db, "devdev-db.nrel.gov", :no_release => true

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/devdev"

# Set the accessible web domain for this site.
set :base_domain, "devdev-new.nrel.gov"

# Reduce the number of copies kept since this is the development environment.
set :keep_releases, 2

# Set the Rails environment.
set :rails_env, "development"
