class Admin
  include Mongoid::Document
  include Mongoid::Paranoia

  # Devise-based authentication using CAS through OmniAuth
  devise :omniauthable, :trackable, :omniauth_providers => [:cas]

  field :username, :type => String
  field :email, :type => String
  field :first_name, :type => String
  field :last_name, :type => String

  index :username, :unique => true

  validates_presence_of :username
  validates_uniqueness_of :username

  def apply_omniauth(omniauth)
    if(extra = omniauth["extra"]["attributes"].first)
      self.first_name = extra["firstName"]
      self.last_name = extra["lastName"]
      self.email = extra["email"]
    end
  end
end
