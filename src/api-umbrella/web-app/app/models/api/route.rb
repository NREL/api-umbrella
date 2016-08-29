class Api::Route
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :matcher, :type => String
  field :http_method, :type => String
  field :from, :type => String
  field :to, :type => String
  field :set_headers, :type => Hash
end
