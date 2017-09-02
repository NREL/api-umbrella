class RateLimit < ApplicationRecord
  alias_attribute :limit, :limit_to

  def serializable_hash(options = nil)
    data = super(options)
    data["limit"] = data.delete("limit_to")
    data
  end
end
