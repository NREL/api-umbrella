class AdminGroup
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  field :created_by, :type => String
  field :updated_by, :type => String
  has_and_belongs_to_many :api_scopes, :class_name => "ApiScope", :inverse_of => nil
  has_and_belongs_to_many :permissions, :class_name => "AdminPermission", :inverse_of => nil
end
