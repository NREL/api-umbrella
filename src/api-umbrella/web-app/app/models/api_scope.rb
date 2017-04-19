require "common_validations"

class ApiScope
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
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
    },
    :uniqueness => {
      :scope => :host,
    }

  def path_prefix_matcher
    /^#{::Regexp.escape(self.path_prefix)}/
  end

  def display_name
    "#{self.name} - #{self.host}#{self.path_prefix}"
  end

  def root?
    (self.path_prefix.blank? || self.path_prefix == "/")
  end

  def self.find_or_create_by_instance!(other)
    attributes = other.attributes.slice("host", "path_prefix")
    record = self.where(attributes).first
    unless(record)
      record = other
      record.save!
    end

    record
  end
end
