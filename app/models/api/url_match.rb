class Api::UrlMatch
  include Mongoid::Document

  # Fields
  field :frontend_prefix, :type => String
  field :backend_prefix, :type => String

  # Relations
  embedded_in :api

  # Mass assignment security
  attr_accessible :_id, :frontend_prefix, :backend_prefix
end
