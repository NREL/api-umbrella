object @api_scope
attributes :id,
           :name,
           :host,
           :path_prefix,
           :created_at,
           :updated_at

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
