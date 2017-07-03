class ApiScope
  include Mongoid::Document
  include Mongoid::Timestamps
  field :_id, :type => String, :overwrite => true, :default => lambda { SecureRandom.uuid }
  field :name, :type => String
  field :host, :type => String
  field :path_prefix, :type => String
  field :created_by, :type => String
  field :updated_by, :type => String

  def self.find_or_create_by_instance!(other)
    attributes = other.attributes.slice("host", "path_prefix")
    record = self.where(:deleted_at => nil).where(attributes).first
    unless(record)
      record = other
      record.save!
    end

    record
  end
end
