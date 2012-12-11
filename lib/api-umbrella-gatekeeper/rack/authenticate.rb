require "rack/request"
require "rack/auth/basic"

require "api-umbrella/api_user"

module ApiUmbrella
  module Gatekeeper
    module Rack
      # Rack middleware to authenticate all incoming API requests. Authentication
      # is based on the "api_key" GET parameter, and validated against our Oracle
      # api_users table.
      #
      # To reuse our ApiUser ActiveRecord model that exists as part of the
      # developer.nrel.gov main_site project, we have a somewhat funky dependency
      # on bootstrapping Rails from the main_site's directory.
      class Authenticate
        def initialize(app, options = {})
          @app = app
          @options = options
        end

        # Authenticate against the ApiUser model.
        def call(env)
          request = ::Rack::Request.new(env)

          # By default, the API key should be passed in through the "api_key" GET
          # parameter.
          env["rack.api_key"] = request.GET["api_key"]

          # Alternatively, we also support the API key being passed as the
          # username during basic HTTP authentication. This makes it easier to
          # authenticate every request inside ActiveResource, since
          # ActiveResource can automatically authenticate every request, but
          # doesn't support passing a specific GET parameter along with every
          # request.
          if(!env["rack.api_key"])
            http_auth = ::Rack::Auth::Basic::Request.new(env)
            if(http_auth.provided? && http_auth.basic?)
              env["rack.api_key"] = http_auth.username
            end
          end

          rack_response = []

          # Authenticate the API key against the database.
          if(env["rack.api_key"] && !env["rack.api_key"].empty?)
            user = ApiUser.where(:api_key => env["rack.api_key"]).first
            if(user)
              # Pass the user object along, so further Rack middleware can access
              # it.
              env["rack.api_user"] = user

              if(!user.disabled_at)
                rack_response = @app.call(env)
              else
                rack_response = [403, {}, ["The api_key supplied has been disabled. Contact us at http://developer.nrel.gov/contact for assistance."]]
              end
            else
              rack_response = [403, {}, ["An invalid api_key was supplied. Get one at http://developer.nrel.gov/"]]
            end
          else
            rack_response = [403, {}, ["No api_key was supplied. Get one at http://developer.nrel.gov/"]]
          end

          rack_response
        end
      end
    end
  end
end
