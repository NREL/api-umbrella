class AdminGroup
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String

  # Relations
  has_and_belongs_to_many :api_scopes, :class_name => "ApiScope", :inverse_of => nil
  has_and_belongs_to_many :permissions, :class_name => "AdminPermission", :inverse_of => nil

  # Validations
  validates :name,
    :presence => true
  validates :api_scopes,
    :presence => true
  validates :permissions,
    :presence => true
  validate :validate_permissions

  def self.sorted
    order_by(:name.asc)
  end

  def can?(permission)
    permissions = self.permission_ids || []
    permissions.include?(permission.to_s)
  end

  def admins
    @admins ||= Admin.where(:group_ids => self.id).all.sorted
  end

  def admin_usernames
    @admin_usernames ||= self.admins.map { |admin| admin.username }
  end

  private

  def validate_permissions
    unknown_permissions = self.permission_ids - [
      "analytics",
      "user_view",
      "user_manage",
      "admin_manage",
      "backend_manage",
      "backend_publish",
    ]

    if(unknown_permissions.any?)
      errors.add(:permission_ids, "unknown permissions: #{unknown_permissions.inspect}")
    end
  end
end
