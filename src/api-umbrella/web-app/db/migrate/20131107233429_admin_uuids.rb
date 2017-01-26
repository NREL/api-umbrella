class AdminUuids < Mongoid::Migration
  def self.up
    original_dynamic = Mongoid.allow_dynamic_fields
    Mongoid.allow_dynamic_fields = true

    db = Mongoid::Sessions.default

    Admin.all.each do |admin|
      # Skip records that already UUIDs.
      next if(admin._id =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)

      if admin.read_attribute(:legacy_id).blank?
        # Duplicate the record (since _id can't be updated) to apply the new
        # UUID _id value.
        new_admin = admin.clone
        new_admin.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(admin._id))
        new_admin._id = SecureRandom.uuid

        puts "#{admin._id} => #{new_admin._id}"

        # Deleting the old record via Mongoid doesn't seem to work now that
        # we're treating _id as a string, so drop down to Moped to delete the
        # old record.
        db[:admins].find(:_id => Moped::BSON::ObjectId.from_string(admin._id.to_s)).remove

        new_admin.save!(:validate => false)
      end
    end

    Admin.all.each do |admin|
      legacy_id = admin.read_attribute(:legacy_id)
      id = admin._id

      if(legacy_id.present?)
        [:admins, :api_users, :apis].each do |collection|
          puts "#{collection}: #{db[collection].find(:created_by => Moped::BSON::ObjectId.from_string(legacy_id.to_s)).to_a.inspect}"
          db[collection].find(:created_by => Moped::BSON::ObjectId.from_string(legacy_id.to_s)).update_all("$set" => { :created_by => id }) # rubocop:disable Rails/SkipsModelValidations
          db[collection].find(:updated_by => Moped::BSON::ObjectId.from_string(legacy_id.to_s)).update_all("$set" => { :updated_by => id }) # rubocop:disable Rails/SkipsModelValidations
        end
      end
    end

    Mongoid.allow_dynamic_fields = original_dynamic
  end

  def self.down
  end
end
