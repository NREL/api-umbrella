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
  embeds_one :settings, :class_name => "Api::Settings"
  embeds_many :servers, :class_name => "Api::Server"
  embeds_many :url_matches, :class_name => "Api::UrlMatch"
  embeds_many :sub_settings, :class_name => "Api::SubSettings"
  embeds_many :rewrites, :class_name => "Api::Rewrite"
  embeds_many :rate_limits, :class_name => "Api::RateLimit"

  # Validations
  validates :name,
    :presence => true
  validates :backend_protocol,
    :inclusion => { :in => %w(http https) }
  validates :frontend_host,
    :presence => true
  validates :backend_host,
    :presence => true
  validates :balance_algorithm,
    :inclusion => { :in => %w(round_robin least_conn ip_hash) }

  # Mass assignment security
  attr_accessible :name,
    :sort_order,
    :backend_protocol,
    :frontend_host,
    :backend_host,
    :balance_algorithm,
    :settings,
    :servers,
    :url_matches,
    :sub_settings,
    :rewrites,
    :rate_limits

  def as_json(options)
    options[:methods] ||= []
    options[:methods] << :required_roles_string

    super(options)
  end
end
