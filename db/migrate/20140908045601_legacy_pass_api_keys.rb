class LegacyPassApiKeys < Mongoid::Migration
  def self.up
    Api.all.each do |api|
      if(api.settings.present?)
        api.settings.pass_api_key_header = true
      end

      if(api.sub_settings.present?)
        api.sub_settings.each do |sub|
          if(sub.settings.present?)
            sub.settings.pass_api_key_header = true
          end
        end
      end

      api.save!
    end
  end

  def self.down
  end
end
