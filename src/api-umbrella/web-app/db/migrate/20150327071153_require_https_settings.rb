class RequireHttpsSettings < Mongoid::Migration
  def self.up
    # The require_https setting that was previously present in the web admin UI
    # was non-functional. So migrate any existing true/false/nil values to the
    # new "optional" setting to replicate the old non-functional behavior.
    Api.all.each do |api|
      if(api.settings.present? && !api.settings.require_https.kind_of?(String))
        api.settings.require_https = "optional"
      end

      if(api.sub_settings.present?)
        api.sub_settings.each do |sub|
          if(sub.settings.present? && !sub.settings.require_https.kind_of?(String))
            sub.settings.require_https = "optional"
          end
        end
      end

      if(api.changed?)
        api.save!(:validate => false)
      end
    end

    active_config = ConfigVersion.active
    active_config.config["apis"].each do |api|
      if(api["settings"].present? && !api["settings"]["require_https"].kind_of?(String))
        api["settings"]["require_https"] = "optional"
      end

      if(api["sub_settings"].present?)
        api["sub_settings"].each do |sub|
          if(sub["settings"].present? && !sub["settings"]["require_https"].kind_of?(String))
            sub["settings"]["require_https"] = "optional"
          end
        end
      end
    end

    if(active_config.changed?)
      active_config.save!(:validate => false)
    end
  end

  def self.down
  end
end
