class ApiUserSettings < ApplicationRecord
  belongs_to :user, :class_name => "ApiUser"
end
