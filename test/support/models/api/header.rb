class Api::Header
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :key, :type => String
  field :value, :type => String
  embedded_in :settings
end
