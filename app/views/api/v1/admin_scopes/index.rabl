collection @admin_scopes, :root => "admin_scopes", :object_root => false
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
