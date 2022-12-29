class ApiRole < ApplicationRecord
  def self.insert_missing(ids)
    if ids.present?
      connection = ApiRole.connection
      ids.each do |id|
        connection.execute("INSERT INTO api_roles(id) VALUES(#{connection.quote(id)}) ON CONFLICT DO NOTHING")
      end
    end
  end

  def self.all_ids
    ApiRole.all.pluck(:id)
  end

  def self.delete_unused
    ApiRole
      .joins("LEFT JOIN api_users_roles ON api_roles.id = api_users_roles.api_role_id")
      .joins("LEFT JOIN api_backend_settings_required_roles ON api_roles.id = api_backend_settings_required_roles.api_role_id")
      .where("api_users_roles.api_user_id IS NULL AND api_backend_settings_required_roles.api_backend_settings_id IS NULL")
      .delete_all
  end
end
