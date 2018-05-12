class FixCustomRateLimits < Mongoid::Migration
  def self.up
    ApiUser.where(:settings.ne => nil).all.each do |user|
      print "."

      rate_limits = user.settings.rate_limits
      if(rate_limits.present?)
        puts "\n#{user.id}: #{user.email}"

        # Force before_validation callbacks to be called even though we're
        # saving with validations disabled. This ensures the automatic accuracy
        # and distributed calculations happen for rate limits.
        user.valid?

        # Assign one of the limits to be primary if that hadn't gotten set.
        if(rate_limits.none? { |limit| limit.response_headers })
          primary = rate_limits.min_by { |limit| limit.duration }
          primary.response_headers = true
        end

        user.save!(:validate => false)
      end
    end

    puts ""
  end

  def self.down
  end
end
