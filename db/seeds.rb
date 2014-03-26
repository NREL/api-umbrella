api = Api.find_or_initialize_by(:name => 'API Umbrella - Default')
api.assign_attributes({
  :frontend_host => ConfigSettings.default_host,
  :backend_host => ConfigSettings.default_host,
  :backend_protocol => 'http',
  :balance_algorithm => 'least_conn',
  :sort_order => 1,
  :servers => [
    {
      'host' => '127.0.0.1',
      'port' => 51_000
    }
  ],
  :url_matches => [
    {
      :frontend_prefix => '/api-umbrella/',
      :backend_prefix => '/api/',
    }
  ],
}, :without_protection => true)
api.save!

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
