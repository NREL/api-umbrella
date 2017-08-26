class ApiUserSettings < ActiveRecord::Base
  belongs_to :user, :class_name => "ApiUser"
end
