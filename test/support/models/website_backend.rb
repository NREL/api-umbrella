class WebsiteBackend
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :frontend_host, :type => String
  field :backend_protocol, :type => String
  field :server_host, :type => String
  field :server_port, :type => Integer
end
