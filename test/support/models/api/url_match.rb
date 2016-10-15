class Api::UrlMatch
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :frontend_prefix, :type => String
  field :backend_prefix, :type => String
  embedded_in :api
end
