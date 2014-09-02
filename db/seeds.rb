user = ApiUser.find_or_initialize_by(:email => 'web.admin.ajax@internal.apiumbrella')
user.assign_attributes({
  :first_name => 'API Umbrella Admin',
  :last_name => 'Key',
  :website => "http://#{ConfigSettings.default_host}/",
  :use_description => 'An API key for the API Umbrella admin to use for internal ajax requests.',
  :terms_and_conditions => '1',
  :registration_source => 'seed',
  :settings_attributes => { :rate_limit_mode => "unlimited" },
}, :without_protection => true)
user.save!

permission = AdminPermission.find_or_initialize_by(:_id => "analytics")
permission.assign_attributes({
  :_id => "analytics",
  :name => "Analytics",
  :display_order => 1,
}, :without_protection => true)
permission.save!

permission = AdminPermission.find_or_initialize_by(:_id => "user_view")
permission.assign_attributes({
  :_id => "user_view",
  :name => "API Users - View",
  :display_order => 2,
}, :without_protection => true)
permission.save!

permission = AdminPermission.find_or_initialize_by(:_id => "user_manage")
permission.assign_attributes({
  :_id => "user_manage",
  :name => "API Users - Manage",
  :display_order => 3,
}, :without_protection => true)
permission.save!

permission = AdminPermission.find_or_initialize_by(:_id => "admin_manage")
permission.assign_attributes({
  :_id => "admin_manage",
  :name => "Admin Accounts - View & Manage",
  :display_order => 4,
}, :without_protection => true)
permission.save!

permission = AdminPermission.find_or_initialize_by(:_id => "backend_manage")
permission.assign_attributes({
  :_id => "backend_manage",
  :name => "API Backend Configuration - View & Manage",
  :display_order => 5,
}, :without_protection => true)
permission.save!

permission = AdminPermission.find_or_initialize_by(:_id => "backend_publish")
permission.assign_attributes({
  :_id => "backend_publish",
  :name => "API Backend Configuration - Publish",
  :display_order => 6,
}, :without_protection => true)
permission.save!
