class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
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

  # Callbacks
  after_save :handle_rate_limit_mode

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
    :rewrites

  def self.sorted
    order_by(:sort_order.asc, :created_at.desc)
  end

  def as_json(options)
    options[:methods] ||= []
    options[:methods] += [:required_roles_string, :error_data_yaml_strings]

    super(options)
  end

  private

  # After the API is saved, clear out any left-over rate_limits for settings
  # where the rate limit mode is no longer "custom."
  #
  # Ideally this would be shifted to a before_validation callback inside the
  # Settings model (so we don't have to explicitly check both #settings and
  # each #sub_settings). However, this doesn't seem to be easily possible.
  # before_validation doesn't quite work because clearing an embedded has_many
  # fires an immediate database query
  # (https://github.com/mongoid/mongoid/issues/2935), but then the new
  # attributes from the api model end up setting it back to what it was.
  # Furthermore, an after_save callback inside the Settings model doesn't work,
  # since those aren't fired on embedded documents by default (and for some
  # reason turning on cascade_callbacks leads to stack level too deep errors).
  def handle_rate_limit_mode
    if(self.settings.present?)
      if(self.settings.rate_limit_mode != "custom")
        self.settings.rate_limits.clear
      end
    end

    if(self.sub_settings.present?)
      self.sub_settings.each do |sub|
        if(sub.settings.present? && sub.settings.rate_limit_mode != "custom")
          sub.settings.rate_limits.clear
        end
      end
    end

    true
  end
end
