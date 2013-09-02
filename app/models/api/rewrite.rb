class Api::Rewrite
  include Mongoid::Document

  # Fields
  field :matcher_type, :type => String
  field :frontend_matcher, :type => String
  field :backend_replacement, :type => String

  # Relations
  embedded_in :api
end
