require "common_validations"

class ApiScope
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :name, :type => String
  field :host, :type => String
  field :path_prefix, :type => String

  # Validations
  validates :name,
    :presence => true
  validates :host,
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    }
  validates :path_prefix,
    :presence => true,
    :format => {
      :with => CommonValidations::URL_PREFIX_FORMAT,
      :message => :invalid_url_prefix_format,
    }

  # Mass assignment security
  attr_accessible :name,
    :host,
    :path_prefix,
    :as => [:admin]

  def path_prefix_matcher
    /^#{Regexp.escape(self.path_prefix)}/
  end

  def display_name
    "#{self.name} - #{self.host}#{self.path_prefix}"
  end

  def root?
    (self.path_prefix.blank? || self.path_prefix == "/")
  end
end
