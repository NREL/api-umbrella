class ApiUserSettings < ApplicationRecord
  belongs_to :user, :class_name => "ApiUser"
  has_many :rate_limits, -> { order(:duration, :limit_by, :limit_to) }

  def serializable_hash(options = nil)
    hash = super(options)
    if hash["allowed_ips"]
      hash["allowed_ips"].map! { |ip| ip.to_s }
    end
    hash
  end
end
