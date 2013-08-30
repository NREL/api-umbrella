class Api::Server
  include Mongoid::Document

  # Fields
  field :host, :type => String
  field :port, :type => Integer

  # Validations
  validates :port,
    :inclusion => { :in => 0..65535 }

  attr_accessible :host, :port
end
