object @api
attributes :id,
           :name,
           :sort_order,
           :backend_protocol,
           :frontend_host,
           :backend_host,
           :balance_algorithm,
           :settings,
           :servers,
           :url_matches,
           :sub_settings,
           :rewrites,
           :created_at,
           :updated_at

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
