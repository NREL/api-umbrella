require "yajl"

require "api_request_log"

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
      class Log
        def initialize(app, options = {})
          @app = app
          @options = options
        end

        # Authenticate against the ApiUser model 
        def call(env)
          # Serialize the raw request environment variables as JSON for storing
          # in the log.
          serialized_env = Yajl::Encoder.encode(env)

          # Call the rest of the Rack middlewares.
          status, headers, response = @app.call(env)

          request = Rack::Request.new(env)

          response_error = nil
          if(status != 200)
            response_error = ""
            response.each { |s| response_error << s.to_s }
          end

          # Create a new log entry for this request.
          log = ApiRequestLog.new({
            :api_key => env["rack.api_key"],
            :path => request.path,
            :ip_address => request.ip,
            :requested_at => Time.now.utc,
            :response_status => status,
            :response_error => response_error,
            :env => serialized_env,
          })

          # Save as quickly as possible - skip validations, and save
          # unsafely/asynchronously (this should actually be the default, but
          # just to be clear, I've specified it here).
          log.save(:validate => false, :safe => false)

          [status, headers, response]
        end
      end
    end
  end
end
