AdminPermission.seed(:id) do |s|
  s.id = "analytics"
  s.name = "Analytics"
  s.display_order = 1
end

AdminPermission.seed(:id) do |s|
  s.id = "user_view"
  s.name = "API Users - View"
  s.display_order = 2
end

AdminPermission.seed(:id) do |s|
  s.id = "user_manage"
  s.name = "API Users - Manage"
  s.display_order = 3
end

AdminPermission.seed(:id) do |s|
  s.id = "admin_manage"
  s.name = "Admin Accounts - View & Manage"
  s.display_order = 4
end

AdminPermission.seed(:id) do |s|
  s.id = "backend_manage"
  s.name = "API Backend Configuration - View & Manage"
  s.display_order = 5
end

AdminPermission.seed(:id) do |s|
  s.id = "backend_publish"
  s.name = "API Backend Configuration - Publish"
  s.display_order = 6
end
