object @admin_group
attributes :id,
           :name,
           :scope_id,
           :access,
           :created_at,
           :updated_at

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
