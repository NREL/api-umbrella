class Api::RateLimit
  include Mongoid::Document

  # Fields
  field :duration, :type => Integer
  field :accuracy, :type => Integer
  field :limit_by, :type => Symbol
  field :limit, :type => Integer
  field :distributed, :type => Boolean
  field :response_headers, :type => Boolean
end
