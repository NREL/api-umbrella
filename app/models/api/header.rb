class Api::Header
  include Mongoid::Document

  # Fields
  field :key, :type => String
  field :value, :type => String

  # Mass assignment security
  attr_accessible :_id, :key, :value
end
