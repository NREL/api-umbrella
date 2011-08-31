require "rack"

if(Rack.release.to_f < 1.3)
  class Rack::Request
    # Override the port method with the version of the method from Rack 1.3.
    # This brings support for the X-Forwarded-Port header we're using since
    # Rails is served up behind HAProxy. Without this support, Rack believes
    # it's being accessed on port 8082, so when it generates URLs (for
    # OmniAuth's CAS ticketing), it'll have redirects to 8082, which isn't
    # accessible to the end user.
    def port
      if port = host_with_port.split(/:/)[1]
        port.to_i
      elsif port = @env['HTTP_X_FORWARDED_PORT']
        port.to_i
      elsif ssl?
        443
      elsif @env.has_key?("HTTP_X_FORWARDED_HOST")
        80
      else
        @env["SERVER_PORT"].to_i
      end
    end
  end
else
  ActiveSupport::Deprecation.warn("Rack monkeypatch no longer needed! config/initializers/rack_forwarded_port_fix.rb is only required for Rack 1.2. Delete this file if Rack has been upgraded to 1.3.")
end
