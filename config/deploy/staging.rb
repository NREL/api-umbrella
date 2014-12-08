if(ENV["API_UMBRELLA_STAGING_ROUTER_SERVERS"].to_s.empty?)
  raise "'API_UMBRELLA_STAGING_ROUTER_SERVERS' environment variable not set.\nSet this environment variable in the '.env' file to a comma-delimited list of server host names you wish to deploy the api-umbrella-router project to."
end

servers = ENV["API_UMBRELLA_STAGING_ROUTER_SERVERS"].to_s.split(",").map do |server|
  "api-umbrella-deploy@#{server}"
end

role :app, servers
role :web, servers
role :db, []
