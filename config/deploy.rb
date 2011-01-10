# Setup our multi-stage environments.
require "capistrano/ext/multistage"

require "capistrano_nrel_ext/recipes/defaults"
require "capistrano_nrel_ext/recipes/haproxy"
require "capistrano_nrel_ext/recipes/server_ports"

# Set the application being deployed.
set :application, "developer_router"

set(:server_registry) do
  {
    # Frontend HAProxy servers.
    :public_router => [
      { :host => domain, :port => 80 },
    ],
    :api_router => [
      { :host => "127.0.0.1", :port => 50001 },
    ],

    # The authentication proxymachine server.
    :auth_proxy => [
      { :host => "127.0.0.1", :port => free_server_port },
    ],

    # The public site.
    :public_site => [
      { :host => "127.0.0.1", :port => 50100 },
    ],

    # API backends.
    # For local services, start assigning ports in the 50500+ range.
    :api_sfv => [
      { :host => "127.0.0.1", :port => 50500 },
    ],
    :api_georeserv => [
      { :host => "rosselli.nrel.gov", :port => 8010 },
    ],
  }
end
