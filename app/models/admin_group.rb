class AdminGroup
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :name, :type => String
  field :access, :type => Array

  # Relations
  belongs_to :scope, :class_name => "AdminScope"

  # Validations
  validate :validate_access

  private

  def validate_access
    unknown_access = self.access - [
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ]

    if(unknown_access.any?)
      errors.add(:access, "unknown access: #{unknown_access.inspect}")
    end
  end
end
