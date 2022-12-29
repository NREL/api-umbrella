class ApiScope < ApplicationRecord
  def self.find_or_create_by_instance!(other)
    attributes = other.attributes.slice("host", "path_prefix")
    record = self.where(attributes).first
    unless(record)
      record = other
      record.save!
    end

    record
  end
end
