# Force a branched deployment on the staging server for the GSA demo.
ENV["BRANCH"] = "gsa"
require "capistrano_nrel_ext/recipes/branches"

# Set the servers for this stage.
role :app, "devstage-int.nrel.gov"
role :web, "devstage-int.nrel.gov"

# Define the primary db server as our app server so database migrations can run
# from the code checkout there.
role :db, "devstage-int.nrel.gov", :primary => true

# On our real database server, don't actually perform a code deployment.
role :db, "devstage-int-db.nrel.gov", :no_release => true

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/devstage-int"

# Set the accessible web domain for this site.
set :base_domain, "stage.api.data.gov"

# Production-ready deployments should exclude git data.
set :copy_exclude, [".git"]

# Set the Rails environment.
set :rails_env, "staging"
