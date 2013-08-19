class Api::UrlMatch
  include Mongoid::Document

  # Fields
  field :frontend_prefix, :type => String
  field :backend_prefix, :type => String
end
