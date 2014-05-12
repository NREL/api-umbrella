object @api_user => :user
attributes :id,
           :api_key_preview,
           :first_name,
           :last_name,
           :email,
           :website,
           :use_description,
           :registration_source,
           :throttle_by_ip,
           :roles,
           :enabled,
           :created_at,
           :updated_at

if((!current_admin || @api_user.created_by == current_admin.id) && Time.now < @api_user.api_key_hides_at)
  attributes :api_key
  attributes :api_key_hides_at
end

child :settings => :settings do
  attributes :id
  attributes :rate_limit_mode
  attributes :allowed_ips
  attributes :allowed_referers

  child :rate_limits, :object_root => false do
    attributes *Api::RateLimit.fields.keys
  end
end

child :creator => :creator do
  attributes :username
end

child :updater => :updater do
  attributes :username
end
