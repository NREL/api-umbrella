class Api::Rewrite
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :matcher_type, :type => String
  field :http_method, :type => String
  field :frontend_matcher, :type => String
  field :backend_replacement, :type => String
  embedded_in :api
end
