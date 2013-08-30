class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :name, :type => String
  field :sort_order, :type => Integer
  field :backend_protocol, :type => String
  field :frontend_host, :type => String
  field :backend_host, :type => String
  field :append_query_string, :type => String
  field :require_https, :type => Boolean
  field :required_roles, :type => Array
  field :balance_algorithm, :type => String

  # Relations
  #embeds_many :headers, :class_name => "Api::Header"
  embeds_many :servers, :class_name => "Api::Server"
  embeds_many :url_matches, :class_name => "Api::UrlMatch"
  embeds_many :rewrites, :class_name => "Api::Rewrite"
  embeds_many :rate_limits, :class_name => "Api::RateLimit"

  # Validations
  validates :backend_protocol,
    :inclusion => { :in => %w(http https) }
  validates :balance_algorithm,
    :inclusion => { :in => %w(round_robin least_conn ip_hash) }

  attr_accessible :name,
    :sort_order,
    :backend_protocol,
    :frontend_host,
    :backend_host,
    :append_query_string,
    :require_https,
    :required_roles,
    :balance_algorithm,
    :servers_attributes,
    :url_matches_attributes,
    :rewrites_attributes,
    :rate_limits_attributes
  accepts_nested_attributes_for :servers, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :url_matches, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :rewrites, :reject_if => :all_blank, :allow_destroy => true
  accepts_nested_attributes_for :rate_limits, :reject_if => :all_blank, :allow_destroy => true
end
