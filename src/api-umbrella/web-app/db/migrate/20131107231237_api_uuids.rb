class ApiUuids < Mongoid::Migration
  def self.up
    original_dynamic = Mongoid.allow_dynamic_fields
    Mongoid.allow_dynamic_fields = true

    db = Mongoid::Sessions.default

    Api.all.each do |api|
      # Skip records that already UUIDs.
      next if(api._id =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)

      if api.read_attribute(:legacy_id).blank?
        # Duplicate the record (since _id can't be updated) to apply the new
        # UUID _id value.
        new_api = api.clone
        new_api.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(api._id))
        new_api._id = SecureRandom.uuid

        if(new_api.settings)
          new_api.settings.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(new_api.settings._id))
          new_api.settings._id = SecureRandom.uuid

          if(new_api.settings.headers)
            new_api.settings.headers.each do |header|
              header.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(header._id))
              header._id = SecureRandom.uuid
            end
          end
        end

        if(new_api.servers)
          new_api.servers.each do |server|
            server.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(server._id))
            server._id = SecureRandom.uuid
          end
        end

        if(new_api.url_matches)
          new_api.url_matches.each do |url_match|
            url_match.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(url_match._id))
            url_match._id = SecureRandom.uuid
          end
        end

        if(new_api.sub_settings)
          new_api.sub_settings.each do |sub_setting|
            sub_setting.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(sub_setting._id))
            sub_setting._id = SecureRandom.uuid

            if(sub_setting.settings)
              sub_setting.settings.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(sub_setting.settings._id))
              sub_setting.settings._id = SecureRandom.uuid

              if(sub_setting.settings.headers)
                sub_setting.settings.headers.each do |header|
                  header.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(header._id))
                  header._id = SecureRandom.uuid
                end
              end
            end
          end
        end

        if(new_api.rewrites)
          new_api.rewrites.each do |rewrite|
            rewrite.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(rewrite._id))
            rewrite._id = SecureRandom.uuid
          end
        end

        if(new_api.read_attribute(:rate_limits))
          new_api.read_attribute(:rate_limits).each do |limit|
            limit.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(limit._id))
            limit._id = SecureRandom.uuid
          end
        end

        puts "#{api._id} => #{new_api._id}"

        # Deleting the old record via Mongoid doesn't seem to work now that
        # we're treating _id as a string, so drop down to Moped to delete the
        # old record.
        db[:apis].find(:_id => Moped::BSON::ObjectId.from_string(api._id.to_s)).remove

        new_api.save!(:validate => false)
      end
    end

    Mongoid.allow_dynamic_fields = original_dynamic
  end

  def self.down
  end
end
