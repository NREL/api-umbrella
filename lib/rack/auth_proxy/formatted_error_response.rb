require "active_support"

module Rack
  module AuthProxy
    class FormattedErrorResponse
      def initialize(app, options = {})
        @app = app
        @options = options
      end

      def call(env)
        status, headers, body = @app.call(env)

        if(status != 200)
          request = Rack::Request.new(env)

          format_extension = ::File.extname(request.path).to_s.downcase
          if(format_extension.empty?)
            format_extension = ".xml"
          end

          headers["Content-Type"] = Rack::Mime.mime_type(format_extension)

          body = self.error_body(format_extension, body.to_s.strip)
        end

        [status, headers, body]
      end

      def error_body(format_extension, message)
        case(format_extension)
        when ".json"
          { :errors => message }.to_json
        when ".xml"
          { :error => message }.to_xml(:root => "errors")
        when ".csv"
          "Error\n#{message}"
        else
          "Error: #{message}"
        end
      end
    end
  end
end
