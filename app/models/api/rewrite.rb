class Api::Rewrite
  include Mongoid::Document

  # Relations
  embedded_in :api
end
