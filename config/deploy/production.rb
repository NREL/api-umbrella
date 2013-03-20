# Force a branched deployment on the production server for the GSA demo.
ENV["BRANCH"] = "gsa"
require "capistrano_nrel_ext/recipes/branches"

# Set the servers for this stage.
role :app, "devprod-int.nrel.gov"
role :web, "devprod-int.nrel.gov"

# Define the primary db server as our app server so database migrations can run
# from the code checkout there.
role :db, "devprod-int.nrel.gov", :primary => true

# On our real database server, don't actually perform a code deployment.
role :db, "devprod-int-db.nrel.gov", :no_release => true

# Set the base path for deployment.
set :deploy_to_base, "/srv/data/devprod-int"

# Set the accessible web domain for this site.
set :base_domain, "api.data.gov"

# Production-ready deployments should exclude git data.
set :copy_exclude, [".git"]

# Set the Rails environment.
set :rails_env, "production"
