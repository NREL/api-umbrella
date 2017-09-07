class ApiUserSettings < ApplicationRecord
  belongs_to :user, :class_name => "ApiUser"
  has_many :rate_limits
end
