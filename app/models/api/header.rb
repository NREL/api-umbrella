class Api::Header
  include Mongoid::Document

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
  field :key, :type => String
  field :value, :type => String

  # Mass assignment security
  attr_accessible :_id, :key, :value
end
