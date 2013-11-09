class Api::RateLimit
  include Mongoid::Document

  # Fields
  field :_id, type: String, default: lambda { UUIDTools::UUID.random_create.to_s }
  field :duration, :type => Integer
  field :accuracy, :type => Integer
  field :limit_by, :type => Symbol
  field :limit, :type => Integer
  field :distributed, :type => Boolean
  field :response_headers, :type => Boolean

  # Relations
  embedded_in :api
end
