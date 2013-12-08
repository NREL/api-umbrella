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
  field :first_name, :type => String
  field :last_name, :type => String

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  index({ :username => 1 }, { :unique => true })

  validates :username,
    :presence => true
  validates :username,
    :uniqueness => true

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
end
