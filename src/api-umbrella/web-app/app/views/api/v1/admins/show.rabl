object @admin
attributes :id,
           :username,
           :email,
           :name,
           :notes,
           :superuser,
           :group_ids,
           :sign_in_count,
           :current_sign_in_at,
           :last_sign_in_at,
           :current_sign_in_ip,
           :last_sign_in_ip,
           :current_sign_in_provider,
           :last_sign_in_provider,
           :created_at,
           :updated_at

if(@admin.id == current_admin.id)
  attributes :authentication_token
end

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
