Rack::Timeout.timeout = ApiUmbrellaConfig[:web][:request_timeout] # seconds

Rack::Timeout::Logger.device = $stderr
Rack::Timeout::Logger.level = Logger::ERROR
