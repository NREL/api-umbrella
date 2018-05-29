class Admin
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  # Devise-based authentication using OmniAuth
  devise :database_authenticatable,
    :omniauthable,
    :recoverable,
    :registerable,
    :rememberable,
    :trackable,
    :lockable

  # Fields
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :username, :type => String
  field :name, :type => String
  field :notes, :type => String
  field :superuser, :type => Boolean
  field :authentication_token, :type => String
  field :current_sign_in_provider, :type => String
  field :last_sign_in_provider, :type => String

  ## Database authenticatable
  field :email, :type => String
  field :encrypted_password, :type => String

  ## Recoverable
  field :reset_password_token, :type => String
  field :reset_password_sent_at, :type => Time

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count, :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at, :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip, :type => String

  ## Lockable
  field :failed_attempts, :type => Integer, :default => 0 # Only if lock strategy is :failed_attempts
  field :unlock_token, :type => String # Only if unlock strategy is :email or :both
  field :locked_at, :type => Time

  # Virtual fields
  attr_accessor :current_password_invalid_reason

  # Relations
  has_and_belongs_to_many :groups, :class_name => "AdminGroup", :inverse_of => nil

  # Indexes
  # This model's indexes are managed by the Mongoose model inside the
  # api-umbrella-router project.
  # index({ :username => 1 }, { :unique => true })

  # Validations
  validates :username,
    :presence => true,
    :uniqueness => true
  validates :username,
    :format => Devise.email_regexp,
    :allow_blank => true,
    :if => :username_is_email?
  validates :email,
    :format => Devise.email_regexp,
    :allow_nil => true,
    :unless => :username_is_email?
  validates :password,
    :presence => true,
    :confirmation => true,
    :if => :password_required?
  validates :password,
    :length => { :in => Devise.password_length },
    :allow_blank => true
  if(ApiUmbrellaConfig[:web][:admin][:password_regex])
    validates :password,
      :format => { :with => ::Regexp.new(ApiUmbrellaConfig[:web][:admin][:password_regex]), :message => :password_format },
      :allow_blank => true
  end
  validates :password_confirmation,
    :presence => true,
    :if => :password_required?
  validate :validate_superuser_or_groups
  validate :validate_current_password

  # Callbacks
  before_validation :sync_username_and_email
  before_validation :generate_authentication_token, :on => :create

  def self.sorted
    order_by(:username.asc)
  end

  def self.needs_first_account?
    ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_enabled][:local] && self.unscoped.count == 0
  end

  def group_names
    unless @group_names
      @group_names = self.groups.sorted.map { |group| group.name }
      if(self.superuser?)
        @group_names << "Superuser"
      end
    end

    @group_names
  end

  def api_scopes
    groups.map { |group| group.api_scopes }.flatten.compact.uniq
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

  # Fetch all the groups this admin belongs to that has a certain permission.
  def groups_with_permission(permission)
    self.groups.select do |group|
      group.can?(permission)
    end
  end

  # Fetch all the API scopes this admin belongs to (through their group
  # membership) that has a certain permission.
  def api_scopes_with_permission(permission)
    self.groups_with_permission(permission).map do |group|
      group.api_scopes
    end.flatten.compact.uniq
  end

  # Fetch all the API scopes this admin belongs to that has a certain
  # permission. Differing from #api_scopes_with_permission, this also includes
  # any nested duplicative scopes.
  #
  # For example, if the user were explicitly granted permissions on a
  # "api.example.com/" scope, this would also return any other sub-scopes that
  # might exist, like "api.example.com/foo" (even if the admin account didn't
  # have explicit permissions on that scope). This can be useful when needing a
  # full list of scope IDs that the admin can operate on (since our prefix
  # based approach means there might be other scopes that exist, but haven't
  # been explicitly granted permissions to).
  def nested_api_scopes_with_permission(permission)
    query_scopes = []
    self.api_scopes_with_permission(permission).each do |api_scope|
      query_scopes << {
        :host => api_scope.host,
        :path_prefix => api_scope.path_prefix_matcher,
      }
    end

    if(query_scopes.any?)
      ApiScope.or(query_scopes).to_a
    else
      []
    end
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

  def serializable_hash(options = nil)
    options ||= {}
    options[:force_except] = options.fetch(:force_except, []) + [
      :authentication_token,
      :encrypted_password,
      :reset_password_token,
      :unlock_token,
    ]
    hash = super(options)
    hash["group_names"] = self.group_names
    hash
  end

  def username_is_email?
    ApiUmbrellaConfig[:web][:admin][:username_is_email]
  end

  # Only require the password fields for validation if they've been entered (if
  # they're left blank, we don't want to require these fields).
  def password_required?
    password.present? || password_confirmation.present?
  end

  def assign_without_password(params, *options)
    params.delete(:password)
    params.delete(:password_confirmation)
    self.assign_attributes(params, *options)
  end

  def assign_with_password(params, *options)
    current_password = params.delete(:current_password)

    # Don't try to set the password unless it was explicitly set.
    if(params[:password].present? || params[:password_confirmation].present?)
      unless(valid_password?(current_password))
        self.current_password_invalid_reason = if(current_password.blank?) then :blank else :invalid end
      end
    else
      params.delete(:password)
      params.delete(:password_confirmation)
    end

    self.assign_attributes(params, *options)
  end

  def send_invite_instructions
    token = nil
    if(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_enabled][:local])
      token = set_invite_reset_password_token
    end

    AdminMailer.invite(self.id, token).deliver_later
  end

  def update_tracked_fields(request)
    old_current = self.current_sign_in_provider
    new_current = "local"
    if(request.env["omniauth.auth"] && request.env["omniauth.auth"]["provider"])
      new_current = request.env["omniauth.auth"]["provider"]
    end
    self.last_sign_in_provider = old_current || new_current
    self.current_sign_in_provider = new_current

    super
  end

  def last_sign_in_provider
    self.read_attribute(:last_sign_in_provider) || self.current_sign_in_provider
  end

  private

  def sync_username_and_email
    if(self.username_is_email?)
      self.email = self.username
    end
  end

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

  def validate_current_password
    if(self.current_password_invalid_reason)
      self.errors.add(:current_password, self.current_password_invalid_reason)
    end
  end

  # Like Devise Recoverable's reset_password_sent_at, but set the
  # reset_password_sent_at date 2 weeks into the future. This allows for the
  # normal reset password valid period to be shorter (6 hours), but we can
  # leverage the same reset password process for the initial invite where we
  # want the period to be longer.
  def set_invite_reset_password_token
    raw, enc = Devise.token_generator.generate(self.class, :reset_password_token)

    self.reset_password_token = enc
    self.reset_password_sent_at = Time.now.utc + 2.weeks
    save(:validate => false)
    raw
  end
end
