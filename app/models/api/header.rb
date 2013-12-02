class Api::Header
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :key, :type => String
  field :value, :type => String

  # Relations
  embedded_in :settings

  # Validations
  validates :key,
    :presence => true

  # Mass assignment security
  attr_accessible :key, :value

  def to_s
    "#{key}: #{value}"
  end
end
