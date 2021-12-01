return if ENV["RAILS_ASSETS_PRECOMPILE"]

Rails.application.config.middleware.insert_after(ActionDispatch::RequestId, Rack::Timeout, :service_timeout => ApiUmbrellaConfig[:web][:request_timeout])

Rack::Timeout::Logger.device = $stderr
Rack::Timeout::Logger.level = Logger::ERROR
