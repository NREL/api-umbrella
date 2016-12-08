class LogCityLocation
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true
  field :country, :type => String
  field :region, :type => String
  field :city, :type => String
  field :location, :type => Hash
  field :updated_at, :type => Time
end
