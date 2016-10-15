class Api::Server
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :host, :type => String
  field :port, :type => Integer
  embedded_in :api
end
