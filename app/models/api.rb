require "api_umbrella/attributify_data"
require "common_validations"

class Api
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Userstamp
  include Mongoid::Paranoia
  include Mongoid::Delorean::Trackable
  include Mongoid::EmbeddedErrors
  include Mongoid::Orderable
  include ApiUmbrella::AttributifyData

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :name, :type => String
  field :sort_order, :type => Integer
  field :backend_protocol, :type => String
  field :frontend_host, :type => String
  field :backend_host, :type => String
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
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    }
  validates :backend_host,
    :presence => true,
    :unless => proc { |record| record.frontend_host.start_with?("*") }
  validates :backend_host,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    },
    :if => proc { |record| record.backend_host.present? }
  validates :balance_algorithm,
    :inclusion => { :in => %w(round_robin least_conn ip_hash) }
  validates_each :servers, :url_matches do |record, attr, value|
    if(value.blank? || (value && value.reject(&:marked_for_destruction?).blank?))
      record.errors.add(:base, "must have at least one #{attr}")
    end
  end

  orderable :column => :sort_order

  # Callbacks
  after_save :handle_rate_limit_mode

  # Nested attributes
  accepts_nested_attributes_for :settings
  accepts_nested_attributes_for :servers, :url_matches, :sub_settings, :rewrites, :allow_destroy => true

  # Mass assignment security
  attr_accessible :name,
    :sort_order,
    :backend_protocol,
    :frontend_host,
    :backend_host,
    :balance_algorithm,
    :settings_attributes,
    :servers_attributes,
    :url_matches_attributes,
    :sub_settings_attributes,
    :rewrites_attributes,
    :as => [:default, :admin]

  def self.sorted
    order_by(:sort_order.asc)
  end

  def attributes_hash
    Hash[self.attributes]
  end

  def as_json(options)
    options[:methods] ||= []
    options[:methods] += [:error_data_yaml_strings, :headers_string, :default_response_headers_string, :override_response_headers_string]

    json = super(options)

    json["api"]["creator"] = {
      "username" => (self.creator.username if(self.creator))
    }

    json["api"]["updater"] = {
      "username" => (self.updater.username if(self.updater))
    }

    json
  end

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

  def handle_transition_https_on_publish!
    if(self.settings)
      self.settings.set_transition_starts_on_publish
    end

    if(self.sub_settings)
      self.sub_settings.each do |sub|
        if(sub.settings)
          sub.settings.set_transition_starts_on_publish
        end
      end
    end

    if(self.changed?)
      self.save!
    end
  end

  def roles
    roles = []

    if(self.settings && self.settings.required_roles)
      roles += self.settings.required_roles
    end

    if(self.sub_settings)
      self.sub_settings.each do |sub|
        if(sub.settings && sub.settings.required_roles)
          roles += sub.settings.required_roles
        end
      end
    end

    roles.uniq!
    roles
  end
end
