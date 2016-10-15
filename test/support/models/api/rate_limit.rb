class Api::RateLimit
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :duration, :type => Integer
  field :accuracy, :type => Integer
  field :limit_by, :type => String
  field :limit, :type => Integer
  field :distributed, :type => Boolean
  field :response_headers, :type => Boolean
  embedded_in :settings
end
