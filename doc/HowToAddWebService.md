# How-to: Add a new web service application backend

In the {file:docs/Architecture.md system architecture}, the web services are implemented inside any number of independent application backends. These backend applications can be written in any programming language and can be configured to respond to any number of arbitrary incoming URLs. When an entirely new backend application is being added to the developer.nrel.gov system, it must first be configured within the system so requests can be routed to it.

*Note:* If a backend application has already been configured (that is, any http://developer.nrel.gov/api requests are already being routed to it), then theses steps have already been followed. In that case, you're probably interested in {file:docs/HowToConfigureUrlEndpoints.md adding additional URL endpoints to an existing web service application backend}.

From the overall architecture diagram, we're only configuring the bottom of the stack:

![Web service application backend architecture](images/architecture_services.png)

The web services router takes in requests after they've been authenticated, and then decides which backend application to pass the request to. Through these steps, we're simply configuring the HAProxy web services router so it knows how to find a specific web services application backend.

1. [Decide where the web service will be hosted](#hosting)
2. [Configure HAProxy](#haproxy)
3. [Commit and redeploy](#redeploy)
4. [Configure URL endpoints to the web service application](#url_endpoints)

<a id="hosting" />
## 1. Decide where the web service will be hosted

You have two options on where your web service may actually live:

* [Locally](#hosting_locally): The web service will be hosted and served alongside other services on developer.nrel.gov.
* [Externally](#hosting_externally): The web service may exist on any other server.

<a id="hosting_locally" />
### Hosting locally on developer.nrel.gov

1. Add your web service code to the `apis` directory.
2. Configure your application's deployment in Capistrano.

The deployment configuration in Capistrano may vary depending on the type and needs of your application. Here's an example of how we configured the Sustainable Fuels & Vehicles web services, a Ruby on Rails-based application.

*Note:* Our Capistrano deployment scripts allow for multiple development sandboxes of our entire stack of applications to be deployed on the same server under different virtual hosts. That's why some of these tasks, like Apache configuration may seem a bit funky at first. Most everything is configured dynamically, so instead of raw Apache config file you may be used to, we're using config file templates that get parsed.

1. Edit the Capistrano deployment script: `config/deploy.rb`
   1. Add a line under `set(:server_process_registry)` for this specific application. This handles deciding which port to host the application server on.

          set(:server_process_registry) do 
            r = default_server_process_registry
            r.add_server(:main_site)
            r.add_server(:auth)
            # ADDING THE FOLLOWING LINE:
            r.add_server(:api_sfv)
            r.add_server(:public, :host => domain, :port => 81)
            r.add_server(:routing)
            r
          end

   2. For Ruby on Rails applications only: Add a line under `set :rails_applications` to the application's path. This simply handles a few other deployment tasks for Ruby on Rails applications.

          set :rails_applications, [
            "main_site",
            # ADDING THE FOLLOWING LINE:
            "apis/sfv",
          ]

1. Configure Apache to serve your application.
   1. Add an Apache configuration file for this application: `config/apache/sites/api_sfv.conf.erb`

          <% server_process_registry.servers(:api_sfv).each do |server_config| %>
            Listen <%= server_config[:port] %>

            <VirtualHost *:<%= server_config[:port] %>>
              ServerName <%= domain %>

              Include <%= current_path %>/config/apache/includes/cache_expiration.conf
              Include <%= current_path %>/config/apache/includes/gzip.conf
              Include <%= current_path %>/config/apache/includes/oracle.conf

              Include <%= current_path %>/config/apache/base_<%= stage %>.conf

              DocumentRoot <%= current_path %>/apis/sfv/public

              CustomLog <%= shared_path %>/log/api-sfv-access.log combined
              ErrorLog <%= shared_path %>/log/api-sfv-error.log
            </VirtualHost>
          <% end %>

   2. Include the application's Apache configuration file in the base Apaache configuration file: `config/apache/base.conf.erb`

          Include <%= current_path %>/config/apache/sites/main_site.conf
          # ADDING THE FOLLOWING LINE:
          Include <%= current_path %>/config/apache/sites/api_sfv.conf

<a id="hosting_externally" />
### Hosting externally

If your web service is already successfully running on an external server, ensure it can be accessed from the developer.nrel.gov and devdev.nrel.gov servers. Then you'll need to add a reference to this external server in the Capistrano deployment script, `config/deploy.rb`:

    set(:server_process_registry) do 
      r = default_server_process_registry
      r.add_server(:main_site)
      r.add_server(:auth)
      r.add_server(:api_sfv)
      # ADDING THE FOLLOWING LINE:
      r.add_server(:api_some_external_example, :host => "other.nrel.gov", :port => 80)
      r.add_server(:public, :host => domain, :port => 81)
      r.add_server(:routing)
      r
    end

<a id="haproxy" />
## 2. Configure HAProxy

1. Add the backend configuration to `config/haproxy/base.cfg.erb`:

       # Sustainable Fuels & Vehicles API Services Backend
       backend <%= deploy_release_name %>-api-sfv-farm
         # Strip /api from the beginning of the request URL before the receiving
         # backend application sees the request.
         #
         # Turns a request from "GET /api/fuel_stations" to "GET /fuel_stations"
         reqirep ^([^\ ]*)\ /api(/.*) \1\ \2

         balance roundrobin
         <% server_process_registry.servers(:api_sfv).each_with_index do |server, i| %>
           server <%= deploy_release_name %>-api-sfv<%= i %> <%= server[:host] %>:<%= server[:port] %> check
         <% end %>

2. Add a new file to determine which URL endpoints get routed to your application: `config/haproxy/routing_matches/api_sfv.lst`
3. Configure the HAProxy routing frontend to route any requests matching URLs in the new `config/haproxy/routing_matches/api_sfv.lst` file to your application:

       # Routing Frontend
       #
       # After authenticating, the auth server sends it back to this routing server
       frontend <%= deploy_release_name %>-routing <%= server_process_registry.servers(:routing).first[:host] %>:<%= server_process_registry.servers(:routing).first[:port] %>
         # ADDING THE FOLLOWING 2 LINES:
         acl url_api_sfv path_beg -i -f <%= File.join(latest_release, "config", "haproxy", "routing_matches", "api_sfv.lst") %>
         use_backend <%= deploy_release_name %>-api-sfv-farm if url_api_sfv

<a id="redeploy" />
## 3. Commit and redeploy

1. Add any new files you've created to subversion. Commit all new and modified files.
2. Redeploy your sandbox using Capistrano. From inside your sandbox (eg, /srv/developer/cttsdev-svc/sandboxes/nmuerdter/developer/current) run:
 
       cap development deploy SANDBOX=your_sandbox_name_here

3. If you've just redeployed your own sandbox, you'll need to `cd` outside of your sandbox, and then back in (the `current` symbolic link has changed paths).

       cd ~
       cd /srv/developer/cttsdev-svc/sandboxes/nmuerdter/developer/current

<a id="url_endpoints" />
## 4. Configure URL endpoints to the web service application

After the web service backend is setup, you must then {file:HowToConfigureUrlEndpoints.md configure the URL endpoints}.
