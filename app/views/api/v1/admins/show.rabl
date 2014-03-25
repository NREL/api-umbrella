object @admin
attributes :id,
           :username,
           :email,
           :name,
           :sign_in_count,
           :last_sign_in_at,
           :last_sign_in_ip,
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
