class UserUuids < Mongoid::Migration
  def self.up
    original_dynamic = Mongoid.allow_dynamic_fields
    Mongoid.allow_dynamic_fields = true

    db = Mongoid::Sessions.default

    ApiUser.all.each do |user|
      # Skip records that already UUIDs.
      next if(user._id =~ /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)

      if user.read_attribute(:legacy_id).blank?
        # Duplicate the record (since _id can't be updated) to apply the new
        # UUID _id value.
        new_user = user.clone
        new_user.write_attribute(:legacy_id, Moped::BSON::ObjectId.from_string(user._id))
        new_user._id = SecureRandom.uuid

        puts "#{user._id} => #{new_user._id}"

        # Deleting the old record via Mongoid doesn't seem to work now that
        # we're treating _id as a string, so drop down to Moped to delete the
        # old record.
        db[:api_users].find(:_id => Moped::BSON::ObjectId.from_string(user._id.to_s)).remove

        new_user.save!(:validate => false)
      end
    end

    users_by_legacy_id = ApiUser.all.to_a.group_by { |user| user.read_attribute(:legacy_id).to_s }
    if(users_by_legacy_id.keys != [""])
      server = Stretcher::Server.new(ElasticsearchConfig.server, :logger => Rails.logger)
      from = 0
      size = 1000
      total = nil
      while(total.nil? || (total && from < total))
        puts "#{from} - #{from + size} of #{total}"

        query_options = { :from => from, :size => size }
        query = {
          :sort => [
            { :request_at => :asc },
          ],
        }

        result = server.index("api-umbrella-logs-*").search(query_options, query)
        total ||= result.total

        result.raw_plain["hits"]["hits"].each do |hit|
          legacy_id = hit["_source"]["user_id"]
          if(legacy_id.present?)
            if(users_by_legacy_id[legacy_id] && users_by_legacy_id[legacy_id].first)
              user = users_by_legacy_id[legacy_id].first
              puts "#{hit["_index"]}/#{hit["_type"]}/#{hit["_id"]}: #{legacy_id} => #{user.id}"
              server.index(hit["_index"]).type(hit["_type"]).update(hit["_id"], :script => "ctx._source.user_id = '#{user.id}'")
            else
              puts "#{hit["_index"]}/#{hit["_type"]}/#{hit["_id"]}: Could not find user id: #{legacy_id}"
            end
          end
        end

        from += size
      end
    end

    Mongoid.allow_dynamic_fields = original_dynamic
  end

  def self.down
  end
end
