module Rack
  module AuthProxy
    class Authorize
      def initialize(app, options = {})
        @app = app
        @options = options
      end

      def call(env)
        request = Rack::Request.new(env)

        required_roles = []
        case(request.path)
        when %r[^/api/(afdc_laws|afv_in_use|afv_of_day|alt_fuel_price_report|biodiesel_consumption|biomass_capacity|cc_coalitions|cc_now|ethanol_consumption|fuel_sales|hev_sales|retail_fuel_prices|transit_buses_fuel_types)]
          required_roles << "vibe"
        when %r[^/api/geocode]
          required_roles << "geocode"
        when %r[^/api/vin]
          required_roles << "vin"
        when %r[^/api/api-user]
          required_roles << "api_user_creation"
        when %r[^/api/fleet_atlas]
          required_roles << "fleet_atlas"
        end

        authorized = true
        required_roles.each do |required_role|
          if(!request.env["rack.api_user"].has_role?(required_role))
            authorized = false
          end
        end

        rack_response = []
        if(authorized)
          rack_response = @app.call(env)
        else
          rack_response = [403, {}, ["The api_key supplied is not authorized to access the given service. Contact us at http://developer.nrel.gov/contact for assistance."]]
        end

        rack_response
      end
    end
  end
end
