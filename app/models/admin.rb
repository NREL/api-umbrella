class Admin
  include Mongoid::Document
  include Mongoid::Paranoia

  # Devise-based authentication using OmniAuth
  devise :omniauthable, :trackable

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

  validates_presence_of :username
  validates_uniqueness_of :username

  def apply_omniauth(omniauth)
    if(omniauth["extra"]["attributes"] && extra = omniauth["extra"]["attributes"].first)
      self.first_name = extra["firstName"]
      self.last_name = extra["lastName"]
      self.email = extra["email"]
    end
  end
end
