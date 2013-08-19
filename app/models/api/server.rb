class Api::Server
  include Mongoid::Document

  # Fields
  field :protocol, :type => String
  field :host, :type => String
  field :port, :type => Integer

  attr_accessible :protocol, :host, :port
end
