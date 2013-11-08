class RemoveLegacyIds < Mongoid::Migration
  def self.up
    # Cleanup the legacy IDs. They shouldn't be needed for any further
    # references. All these models are tracked in Mongoid::Delorean, so if the
    # old IDs need to really be fetched, they're in there.
    ApiUser.all.each do |user|
      if user.has_attribute?(:legacy_id)
        user.remove_attribute(:legacy_id)
        user.save(:validate => false)
      end
    end

    Admin.all.each do |admin|
      if admin.has_attribute?(:legacy_id)
        admin.remove_attribute(:legacy_id)
        admin.save(:validate => false)
      end
    end

    Api.all.each do |api|
      if api.has_attribute?(:legacy_id)
        api.remove_attribute(:legacy_id)

        if(api.settings)
          if api.settings.has_attribute?(:legacy_id)
            api.settings.remove_attribute(:legacy_id)
          end

          if(api.settings.headers)
            api.settings.headers.each do |header|
              if header.has_attribute?(:legacy_id)
                header.remove_attribute(:legacy_id)
              end
            end
          end
        end

        if(api.servers)
          api.servers.each do |server|
            if server.has_attribute?(:legacy_id)
              server.remove_attribute(:legacy_id)
            end
          end
        end

        if(api.url_matches)
          api.url_matches.each do |url_match|
            if url_match.has_attribute?(:legacy_id)
              url_match.remove_attribute(:legacy_id)
            end
          end
        end

        if(api.sub_settings)
          api.sub_settings.each do |sub_setting|
            if sub_setting.has_attribute?(:legacy_id)
              sub_setting.remove_attribute(:legacy_id)
            end

            if(sub_setting.settings)
              if sub_setting.settings.has_attribute?(:legacy_id)
                sub_setting.settings.remove_attribute(:legacy_id)
              end

              if(sub_setting.settings.headers)
                sub_setting.settings.headers.each do |header|
                  if header.has_attribute?(:legacy_id)
                    header.remove_attribute(:legacy_id)
                  end
                end
              end
            end
          end
        end

        if(api.rewrites)
          api.rewrites.each do |rewrite|
            if rewrite.has_attribute?(:legacy_id)
              rewrite.remove_attribute(:legacy_id)
            end
          end
        end

        if(api.rate_limits)
          api.rate_limits.each do |limit|
            if limit.has_attribute?(:legacy_id)
              limit.remove_attribute(:legacy_id)
            end
          end
        end

        api.save(:validate => false)
      end
    end
  end

  def self.down
  end
end
