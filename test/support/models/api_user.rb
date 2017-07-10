class ApiUser < ActiveRecord::Base
  def api_key_preview
    self.api_key.truncate(9)
  end
end
