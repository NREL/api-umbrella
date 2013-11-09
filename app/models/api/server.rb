class Api::Server
  include Mongoid::Document

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
  field :host, :type => String
  field :port, :type => Integer

  # Relations
  embedded_in :api

  # Validations
  validates :port,
    :inclusion => { :in => 0..65535 }

  # Mass assignment security
  attr_accessible :_id, :host, :port
end
