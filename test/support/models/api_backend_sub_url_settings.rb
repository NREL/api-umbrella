class ApiBackendSubUrlSettings < ActiveRecord::Base
  belongs_to :api_backend
  has_one :settings, :class_name => "ApiBackendSettings"
end
