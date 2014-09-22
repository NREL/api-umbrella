class Admin
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Devise-based authentication using OmniAuth
  devise :omniauthable, :trackable

  # Fields
  field :_id, :type => String, :default => lambda { UUIDTools::UUID.random_create.to_s }
  field :username, :type => String
  field :email, :type => String
  field :name, :type => String
  field :notes, :type => String
  field :superuser, :type => Boolean
  field :authentication_token, :type => String
  field :last_sign_in_provider, :type => String

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  # Relations
  has_and_belongs_to_many :groups, :class_name => "AdminGroup", :inverse_of => nil

  # Indexes
  index({ :username => 1 }, { :unique => true })

  # Validations
  validates :username,
    :presence => true,
    :uniqueness => true
  validate :validate_superuser_or_groups

  # Callbacks
  before_validation :generate_authentication_token, :on => :create

  # Mass assignment security
  attr_accessible :username,
    :email,
    :name,
    :notes,
    :superuser,
    :group_ids,
    :as => [:admin]

  def api_scopes
    @api_scopes ||= groups.map { |group| group.api_scopes }.flatten.compact.uniq
  end

  def can?(permission)
    allowed = false

    if(self.superuser?)
      allowed = true
    else
      allowed = self.groups.any? do |group|
        group.can?(permission)
      end
    end

    allowed
  end

  def can_any?(permissions)
    [permissions].flatten.compact.any? do |permission|
      self.can?(permission)
    end
  end

  def groups_with_permission(permission)
    self.groups.select do |group|
      group.can?(permission)
    end
  end

  def api_scopes_with_permission(permission)
    self.groups_with_permission(permission).map do |group|
      group.api_scopes
    end.flatten.compact.uniq
  end

  def apply_omniauth(omniauth)
    if(omniauth["extra"]["attributes"])
      extra = omniauth["extra"]["attributes"].first
      if(extra)
        self.first_name = extra["firstName"]
        self.last_name = extra["lastName"]
        self.email = extra["email"]
      end
    end
  end

  def disallowed_roles
    unless @disallowed_roles
      allowed_apis = ApiPolicy::Scope.new(self, Api.all).resolve(:any)
      allowed_apis = allowed_apis.to_a.select { |api| Pundit.policy!(self, api).set_user_role? }

      all_api_roles = Api.all.map { |api| api.roles }.flatten
      allowed_api_roles = allowed_apis.map { |api| api.roles }.flatten

      @disallowed_roles = all_api_roles - allowed_api_roles
    end

    @disallowed_roles
  end

  private

  def generate_authentication_token
    unless self.authentication_token
      # Generate a key containing A-Z, a-z, and 0-9 that's 40 chars in
      # length.
      key = ""
      while key.length < 40
        key = SecureRandom.base64(50).delete("+/=")[0, 40]
      end

      self.authentication_token = key
    end
  end

  def validate_superuser_or_groups
    if(!self.superuser? && self.groups.blank?)
      self.errors.add(:groups, "must belong to at least one group or be a superuser")
    end
  end
end
