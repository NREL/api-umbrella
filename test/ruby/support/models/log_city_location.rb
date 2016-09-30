class LogCityLocation
  include Mongoid::Document
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :country, :type => String
  field :region, :type => String
  field :city, :type => String
  field :location, :type => Hash
  field :updated_at, :type => Time
end
