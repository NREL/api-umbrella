class Api::Server
  include Mongoid::Document

  # Fields
  field :host, :type => String
  field :port, :type => Integer

  # Relations
  embedded_in :api

  # Validations
  validates :port,
    :inclusion => { :in => 0..65535 }

  # Mass assignment security
  attr_accessible :host, :port
end
