class AdminPermission
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  include Mongoid::Userstamp
  include Mongoid::Delorean::Trackable

  field :_id, :type => String, :overwrite => true
  field :name, :type => String
  field :display_order, :type => Integer

  def self.sorted
    order_by(:display_order.asc)
  end
end
