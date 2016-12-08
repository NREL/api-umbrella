class AdminPermission
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true
  field :name, :type => String
  field :display_order, :type => Integer
end
