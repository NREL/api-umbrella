class AdminGroup < ApplicationRecord
  has_and_belongs_to_many :api_scopes, -> { order(:name) }
  has_and_belongs_to_many :permissions, -> { order(:display_order) }, :class_name => "AdminPermission", :join_table => "admin_groups_admin_permissions"

  def serializable_hash(options = nil)
    options ||= {}
    options.merge!({
      :methods => [
        :api_scope_ids,
        :permission_ids,
      ],
      :include => {
        :api_scopes => {},
        :permissions => {},
      },
    })
    super(options)
  end
end
