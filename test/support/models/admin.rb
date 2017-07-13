class Admin
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :username, :type => String
  field :name, :type => String
  field :notes, :type => String
  field :superuser, :type => Boolean
  field :authentication_token, :type => String, :default => lambda { SecureRandom.hex(20) }
  field :current_sign_in_provider, :type => String
  field :last_sign_in_provider, :type => String
  field :email, :type => String
  field :encrypted_password, :type => String
  field :reset_password_token, :type => String
  field :reset_password_sent_at, :type => Time
  field :remember_created_at, :type => Time
  field :sign_in_count, :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at, :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip, :type => String
  field :failed_attempts, :type => Integer, :default => 0
  field :unlock_token, :type => String
  field :locked_at, :type => Time
  field :created_by, :type => String
  field :updated_by, :type => String
  has_and_belongs_to_many :groups, :class_name => "AdminGroup", :inverse_of => nil
end
