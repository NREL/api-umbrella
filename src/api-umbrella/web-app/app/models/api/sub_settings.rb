class Api::SubSettings
  include Mongoid::Document

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :http_method, :type => String
  field :regex, :type => String

  # Relations
  embedded_in :api
  embeds_one :settings, :class_name => "Api::Settings"

  # Validations
  validates :http_method,
    :inclusion => { :in => %w(any GET POST PUT DELETE HEAD TRACE OPTIONS CONNECT PATCH) }
  validates :regex,
    :presence => true

  # Nested attributes
  accepts_nested_attributes_for :settings

  def serializable_hash(options = nil)
    hash = super(options)
    # Ensure all embedded relationships are at least null in the JSON output
    # (rather than not being present), or else Ember-Data's serialization
    # throws warnings.
    hash["settings"] ||= nil
    hash
  end
end
