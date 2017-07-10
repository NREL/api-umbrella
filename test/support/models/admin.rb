class Admin < ActiveRecord::Base
  has_and_belongs_to_many :groups, :class => "AdminGroup"
end
