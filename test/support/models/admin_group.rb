class AdminGroup < ActiveRecord::Base
  has_and_belongs_to_many :api_scopes
  has_and_belongs_to_many :permissions, :class_name => "AdminPermission", :join_table => "admin_groups_admin_permissions"
end
