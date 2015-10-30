class CustomRateLimits < Mongoid::Migration
  def self.up
    ApiUser.all.each do |user|
      print "."

      unthrottled = user.read_attribute(:unthrottled)
      hourly_limit = user.read_attribute(:throttle_hourly_limit)
      daily_limit = user.read_attribute(:throttle_daily_limit)

      user.build_settings unless(user.settings)

      if(unthrottled.present?)
        user.settings.rate_limit_mode = "unlimited"
      end

      if(hourly_limit.present? || daily_limit.present?)
        user.settings.rate_limit_mode = "custom"

        limit_by = "apiKey"
        if(user.throttle_by_ip)
          limit_by = "ip"
        end

        if(hourly_limit.present?)
          user.settings.rate_limits.build({
            :duration => 3_600_000,
            :limit_by => limit_by,
            :limit => hourly_limit,
          })
        end

        if(daily_limit.present?)
          user.settings.rate_limits.build({
            :duration => 86_400_000,
            :limit_by => limit_by,
            :limit => daily_limit,
          })
        end
      end

      if(unthrottled.present? || hourly_limit.present? || daily_limit.present?)
        user.remove_attribute(:unthrottled)
        user.remove_attribute(:throttle_hourly_limit)
        user.remove_attribute(:throttle_daily_limit)

        puts "\n#{user.id}: #{user.email}: #{unthrottled.inspect}, #{hourly_limit.inspect}, #{daily_limit.inspect}"

        user.save!(:validate => false)
      end
    end

    puts ""
  end

  def self.down
  end
end
