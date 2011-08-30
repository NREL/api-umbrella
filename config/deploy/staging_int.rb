require "capistrano_nrel_ext/recipes/branches"

# Set the servers for this stage.
role :app, "devstage-int.nrel.gov"
role :web, "devstage-int.nrel.gov"

# Set the base path for deployment.
set :deploy_to_base, "/srv/developer/devstage-int"

# Set the accessible web domain for this site.
set :base_domain, "devstage-int.nrel.gov"

# Set the Rails environment.
set :rails_env, "staging_int"
