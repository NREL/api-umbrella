# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

# Deploy this application under a sub URL if Rails has a relative_url_root.
map ActionController::Base.config.relative_url_root || "/" do
  run Developer::Application
end
