require "common_validations"

class WebsiteBackend
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :frontend_host, :type => String
  field :backend_protocol, :type => String
  field :server_host, :type => String
  field :server_port, :type => Integer

  # Validations
  validates :frontend_host,
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT_WITH_WILDCARD,
      :message => :invalid_host_format,
    }
  validates :backend_protocol,
    :inclusion => { :in => ["http", "https"] }
  validates :server_host,
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT,
      :message => :invalid_host_format,
    }
  validates :server_port,
    :presence => true,
    :inclusion => { :in => 0..65_535 }

  def self.sorted
    order_by(:frontend_host.asc)
  end

  def attributes_hash
    self.attributes.to_h
  end
end
