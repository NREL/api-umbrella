class RateLimit < ApplicationRecord
  def serializable_hash(options = nil)
    data = super(options)
    data["limit"] = data.delete("limit_to")
    if data["limit_by"] == "api_key"
      data["limit_by"] = "apiKey"
    end
    data
  end
end
