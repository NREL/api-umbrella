class Api::Header
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :key, :type => String
  field :value, :type => String

  # Relations
  embedded_in :settings

  # Validations
  validates :key,
    :presence => true

  def to_s
    "#{key}: #{value}"
  end
end
