object @website_backend
attributes :id,
           :frontend_host,
           :backend_protocol,
           :server_host,
           :server_port,
           :created_at,
           :updated_at

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
