class ApiRole < ApplicationRecord
  def self.insert_missing(ids)
    if ids.present?
      connection = ApiRole.connection
      ids.each do |id|
        connection.execute("INSERT INTO api_roles(id) VALUES(#{connection.quote(id)}) ON CONFLICT DO NOTHING")
      end
    end
  end
end
