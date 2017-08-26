class ApiBackendSettings < ActiveRecord::Base
  belongs_to :api_backend
  has_many :rate_limits
end
