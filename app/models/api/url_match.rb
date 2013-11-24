class Api::UrlMatch
  include Mongoid::Document

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
  field :frontend_prefix, :type => String
  field :backend_prefix, :type => String

  # Relations
  embedded_in :api

  # Mass assignment security
  attr_accessible :frontend_prefix,
    :backend_prefix
end
