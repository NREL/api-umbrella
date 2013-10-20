class UserUuids < Mongoid::Migration
  def self.up
    original_dynamic = Mongoid.allow_dynamic_fields
    Mongoid.allow_dynamic_fields = true

    db = Mongoid::Sessions.default

    ApiUser.all.each do |user|
      if user.legacy_id.blank?
        # Duplicate the record (since _id can't be updated) to apply the new
        # UUID _id value.
        new_user = user.clone
        new_user.legacy_id = Moped::BSON::ObjectId.from_string(user._id)
        new_user._id = UUIDTools::UUID.random_create.to_s

        puts "#{user._id.to_s} => #{new_user._id}"

        # Deleting the old record via Mongoid doesn't seem to work now that
        # we're treating _id as a string, so drop down to Moped to delete the
        # old record.
        db[:api_users].find(:_id => Moped::BSON::ObjectId.from_string(user._id.to_s)).remove

        new_user.save!(:validate => false)
      end
    end

    users_by_legacy_id = ApiUser.all.to_a.group_by { |user| user.legacy_id.to_s }
    server = Stretcher::Server.new(ElasticsearchConfig.server, :logger => Rails.logger)

    from = 0
    size = 1000
    total = nil
    while(total.nil? || (total && from < total))
      puts "#{from} - #{from + size} of #{total}"
      result = server.index("api-umbrella-logs-*").search(:from => from, :size => size)
      total ||= result.total

      result.raw_plain["hits"]["hits"].each do |hit|
        legacy_id = hit["_source"]["user_id"]
        if(legacy_id.present?)
          if(users_by_legacy_id[legacy_id] && users_by_legacy_id[legacy_id].first)
            user = users_by_legacy_id[legacy_id].first
            puts "#{hit["_id"]}: #{legacy_id} => #{user.id}"
            server.index(hit["_index"]).type(hit["_type"]).update(hit["_id"], :script => "ctx._source.user_id = '#{user.id}'")
          else
            puts "Could not find user id: #{legacy_id}"
          end
        end
      end

      from += size
    end

    Mongoid.allow_dynamic_fields = original_dynamic
  end

  def self.down
  end
end
