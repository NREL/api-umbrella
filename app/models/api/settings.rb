class Api::Settings
  include Mongoid::Document

  # Fields
  field :append_query_string, :type => String
  field :http_basic_auth, :type => String
  field :require_https, :type => Boolean
  field :disable_api_key, :type => Boolean
  field :required_roles, :type => Array
  field :hourly_rate_limit, :type => Integer

  # Relations
  embeds_many :headers, :class_name => "Api::Header"
  embedded_in :api
  embedded_in :sub_settings

  # Mass assignment security
  attr_accessible :append_query_string,
    :http_basic_auth,
    :require_https,
    :disable_api_key,
    :required_roles,
    :hourly_rate_limit
  accepts_nested_attributes_for :headers, :reject_if => :all_blank, :allow_destroy => true
end
