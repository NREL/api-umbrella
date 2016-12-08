class Api::Settings
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => String
  field :require_https_transition_start_at, :type => Time
  field :disable_api_key, :type => Boolean
  field :api_key_verification_level, :type => String
  field :api_key_verification_transition_start_at, :type => Time
  field :required_roles, :type => Array
  field :required_roles_override, :type => Boolean
  field :allowed_ips, :type => Array
  field :allowed_referers, :type => Array
  field :rate_limit_mode, :type => String
  field :anonymous_rate_limit_behavior, :type => String
  field :authenticated_rate_limit_behavior, :type => String
  field :pass_api_key_header, :type => Boolean
  field :pass_api_key_query_param, :type => Boolean
  field :error_templates, :type => Hash
  field :error_data, :type => Hash
  embeds_many :headers, :class_name => "Api::Header"
  embeds_many :rate_limits, :class_name => "Api::RateLimit"
  embeds_many :default_response_headers, :class_name => "Api::Header"
  embeds_many :override_response_headers, :class_name => "Api::Header"
  embedded_in :api
  embedded_in :sub_settings
  embedded_in :api_user
end
