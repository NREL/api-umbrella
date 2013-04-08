module ApiUmbrella
  module Gatekeeper
    class RequestParserHandler < HttpParserHandler
      HTTP_PREFIX     = 'HTTP_'
      SERVER_NAME     = 'SERVER_NAME'
      SERVER_PORT     = 'SERVER_PORT'
      REMOTE_ADDR     = 'REMOTE_ADDR'
      CONTENT_LENGTH  = 'CONTENT_LENGTH'
      SCRIPT_NAME  = 'SCRIPT_NAME'
      CONTENT_TYPE    = 'CONTENT_TYPE'
      REQUEST_METHOD  = 'REQUEST_METHOD'
      REQUEST_URI     = 'REQUEST_URI'
      QUERY_STRING    = 'QUERY_STRING'
      HTTP_VERSION    = 'HTTP_VERSION'
      REQUEST_PATH    = 'REQUEST_PATH'
      PATH_INFO       = 'PATH_INFO'
      FRAGMENT        = 'FRAGMENT'
      CONNECTION      = 'CONNECTION'
      UPGRADE_DATA    = 'UPGRADE_DATA'
      REMOTE_ADDR    = 'REMOTE_ADDR'
      RACK_INPUT    = 'rack.input'
      RACK_URL_SCHEME    = 'rack.url_scheme'
      RACK_ERRORS    = 'rack.errors'
      RACK_VERSION    = 'rack.version'
      RACK_MULTITHREAD    = 'rack.multithread'
      RACK_MULTIPROCESS    = 'rack.multiprocess'
      RACK_RUN_ONCE    = 'rack.run_once'
      RACK_VERSION_NUM    = [1, 2]

      def on_headers_complete(headers)
        #p [:request, :on_headers_complete, headers]
        env = rack_env(headers)
        connection_handler.request_headers_parsed(env)
      end

      def on_body(chunk)
        #p [:request, :on_body, chunk]
      end

      def on_message_complete
        connection_handler.request_completed = true
      end

      private

      def rack_env(headers)
        rack_env = {}

        headers.each do |header, value|
          rack_env[HTTP_PREFIX + header.gsub('-','_').upcase] = value
        end

        %w(CONTENT_TYPE CONTENT_LENGTH).each do |name|
          rack_env[name] = rack_env.delete("HTTP_#{name}") if rack_env["HTTP_#{name}"]
        end

        if rack_env['HTTP_HOST']
          name, port = rack_env['HTTP_HOST'].split(':')
          rack_env[SERVER_NAME] = name if name
          rack_env[SERVER_PORT] = port if port
        end

        rack_env[REQUEST_METHOD]  = parser.http_method
        rack_env[SCRIPT_NAME]     = ""
        rack_env[PATH_INFO]       = parser.request_path
        rack_env[QUERY_STRING]    = parser.query_string
        rack_env[REQUEST_URI]     = parser.request_url
        rack_env[REQUEST_PATH]    = parser.request_path
        rack_env[FRAGMENT]        = parser.fragment
        rack_env[HTTP_VERSION]    = parser.http_version.join('.')
        rack_env[REMOTE_ADDR] = if(connection_handler.connection.peer) then connection_handler.connection.peer.first else nil end
        rack_env[RACK_VERSION] = RACK_VERSION_NUM
        rack_env[RACK_URL_SCHEME] = if(rack_env["HTTPS"]) then "https" else "http" end
        rack_env[RACK_INPUT] = StringIO.new
        rack_env[RACK_INPUT].set_encoding("ASCII-8BIT")
        rack_env[RACK_ERRORS] = STDERR
        rack_env[RACK_MULTITHREAD] = false
        rack_env[RACK_MULTIPROCESS] = false
        rack_env[RACK_RUN_ONCE] = false

        rack_env
      end
    end
  end
end
