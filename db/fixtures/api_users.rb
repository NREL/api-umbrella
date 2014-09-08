ApiUser.seed(:email) do |s|
  s.email = "web.admin.ajax@internal.apiumbrella"
  s.first_name = "API Umbrella Admin"
  s.last_name = "Key"
  s.website = "http://#{ApiUmbrellaConfig[:default_host]}/"
  s.use_description = "An API key for the API Umbrella admin to use for internal ajax requests."
  s.terms_and_conditions = "1"
  s.registration_source = "seed"
  s.settings_attributes = { :rate_limit_mode => "unlimited" }
end
