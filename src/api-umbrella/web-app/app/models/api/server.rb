require "common_validations"
require "resolv"

class Api::Server
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :host, :type => String
  field :port, :type => Integer

  # Relations
  embedded_in :api

  # Validations
  validates :host,
    :presence => true,
    :format => {
      :with => CommonValidations::HOST_FORMAT,
      :message => :invalid_host_format,
    }
  validates :port,
    :presence => true,
    :inclusion => { :in => 0..65_535 }
  validate :validate_host_resolves, :on => :create

  private

  def validate_host_resolves
    if(self.host.present?)
      begin
        Resolv.getaddress(self.host)
      rescue => error
        self.errors.add(:host, "Could not resolve host: #{error.message}")
      end
    end
  end
end
