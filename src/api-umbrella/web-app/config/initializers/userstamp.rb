module Mongoid
  module Userstamp
    extend ActiveSupport::Concern

    included do
      belongs_to :creator, :class_name => "Admin", :foreign_key => :created_by
      belongs_to :updater, :class_name => "Admin", :foreign_key => :updated_by

      before_create :set_created_by
      before_save :set_updated_by

      protected

      def set_created_by
        current_user = RequestStore.store[:current_userstamp_user]
        if(current_user && !self.created_by_changed?)
          self.created_by = current_user.id
        end
      end

      def set_updated_by
        current_user = RequestStore.store[:current_userstamp_user]
        if(current_user && !self.updated_by_changed?)
          self.updated_by = current_user.id
        end
      end
    end
  end
end
